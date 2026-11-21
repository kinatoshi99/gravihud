import Foundation

/// Pure read-only scanner for local Antigravity conversation transcripts:
///   `<appData>/brain/<uuid>/.system_generated/logs/transcript.jsonl`
///
/// Never modifies Antigravity files, never touches SQLite or credentials, never performs network I/O.
final class TranscriptScanner {
    static let uuidRegex = try! NSRegularExpression(
        pattern: #"^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$"#,
        options: []
    )
    private static let userRequestRegex = try! NSRegularExpression(
        pattern: #"<USER_REQUEST>\s*([\s\S]*?)\s*</USER_REQUEST>"#,
        options: [.caseInsensitive]
    )

    private struct CacheEntry {
        let mtimeMs: Int64
        let size: UInt64
        let parsed: ConversationMetrics
    }

    private let lock = NSLock()
    private var cache: [String: CacheEntry] = [:]

    private let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoStandard: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    let brainDir: URL

    init(appDataDir: URL? = nil) {
        let base = appDataDir ?? TranscriptScanner.defaultAppDataDir()
        self.brainDir = base.appendingPathComponent("brain", isDirectory: true)
    }

    static func defaultAppDataDir() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".gemini", isDirectory: true)
            .appendingPathComponent("antigravity", isDirectory: true)
    }

    static func isValidUUID(_ value: String) -> Bool {
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return uuidRegex.firstMatch(in: value, options: [], range: range) != nil
    }

    private func parseTimestampMs(_ raw: Any?) -> Int64 {
        guard let str = raw as? String, !str.isEmpty else { return 0 }
        if let d = isoFractional.date(from: str) {
            return Int64((d.timeIntervalSince1970 * 1000.0).rounded())
        }
        if let d = isoStandard.date(from: str) {
            return Int64((d.timeIntervalSince1970 * 1000.0).rounded())
        }
        return 0
    }

    private func int64Value(_ raw: Any?) -> Int64 {
        if let n = raw as? NSNumber {
            return max(0, n.int64Value)
        }
        if let s = raw as? String, let v = Int64(s) {
            return max(0, v)
        }
        return 0
    }

    private func extractTitle(from content: String) -> String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        var candidate = trimmed
        let nsRange = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        if let match = TranscriptScanner.userRequestRegex.firstMatch(in: trimmed, options: [], range: nsRange),
           let innerRange = Range(match.range(at: 1), in: trimmed) {
            candidate = String(trimmed[innerRange])
        }

        let singleLine = candidate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if singleLine.count <= 68 {
            return singleLine
        }
        let endIdx = singleLine.index(singleLine.startIndex, offsetBy: 67)
        return String(singleLine[..<endIdx]) + "…"
    }

    func parseTranscript(
        text: String,
        conversationId: String,
        fallbackMtimeMs: Int64,
        nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)
    ) -> ConversationMetrics {
        let lines = text.split(omittingEmptySubsequences: true, whereSeparator: { $0 == "\n" || $0 == "\r" })

        var title = ""
        var userTurns = 0
        var firstMs: Int64 = 0
        var lastMs: Int64 = 0
        var prevStepMs: Int64 = 0

        var steps: [StepMetrics] = []
        var totalIn: Int64 = 0
        var totalCache: Int64 = 0
        var totalOut: Int64 = 0
        var totalCost = 0.0
        var totalSaved = 0.0
        var pricedSteps = 0
        var unpricedSteps = 0
        var toolCallsTotal = 0
        var subagentCallsTotal = 0

        var globalToolCounts: [String: Int] = [:]
        var modelAccum: [String: (
            short: String,
            family: String,
            steps: Int,
            input: Int64,
            cache: Int64,
            output: Int64,
            cost: Double,
            saved: Double,
            hasPrice: Bool
        )] = [:]

        for rawLine in lines {
            let trimmedLine = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedLine.hasPrefix("{"), trimmedLine.hasSuffix("}"),
                  let data = trimmedLine.data(using: .utf8),
                  let obj = (try? JSONSerialization.jsonObject(with: data, options: [])) as? [String: Any]
            else {
                // Gracefully tolerate a torn/incomplete trailing line while Antigravity is actively writing.
                continue
            }

            let createdAtMs = parseTimestampMs(obj["created_at"])
            if createdAtMs > 0 {
                if firstMs == 0 || createdAtMs < firstMs { firstMs = createdAtMs }
                if createdAtMs > lastMs { lastMs = createdAtMs }
            }

            let stepType = (obj["type"] as? String ?? "").uppercased()
            let source = (obj["source"] as? String ?? "").uppercased()

            if stepType == "USER_INPUT" || source == "USER_EXPLICIT" {
                userTurns += 1
                if title.isEmpty, let content = obj["content"] as? String {
                    let extracted = extractTitle(from: content)
                    if !extracted.isEmpty {
                        title = extracted
                    }
                }
            }

            let inTok = int64Value(obj["input_tokens"])
            let cacheTok = int64Value(obj["cache_read_tokens"])
            let outTok = int64Value(obj["output_tokens"])
            let modelStr = (obj["model"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let hasUsage = (inTok > 0 || cacheTok > 0 || outTok > 0) || (!modelStr.isEmpty && stepType == "PLANNER_RESPONSE")

            guard hasUsage else { continue }

            let stepIndex = Int(int64Value(obj["step_index"]))
            let effectiveModel = modelStr.isEmpty ? "unknown" : modelStr
            let modelShort = OfflinePricing.shortName(effectiveModel)
            let family = OfflinePricing.inferFamily(effectiveModel)

            let contextTokens = inTok + cacheTok
            let totalTokens = contextTokens + outTok
            let cacheHitPct = contextTokens > 0
                ? ((Double(cacheTok) / Double(contextTokens)) * 1000.0).rounded() / 10.0
                : 0.0

            let (costUsd, savedUsd) = OfflinePricing.estimateCost(
                model: effectiveModel,
                inputTokens: inTok,
                cacheReadTokens: cacheTok,
                outputTokens: outTok
            )

            var stepToolCounts: [String: Int] = [:]
            var stepSubagents = 0
            if let toolCalls = obj["tool_calls"] as? [[String: Any]] {
                for tc in toolCalls {
                    let name = (tc["name"] as? String ?? tc["tool_name"] as? String ?? "tool")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let cleanName = name.isEmpty ? "tool" : name
                    stepToolCounts[cleanName, default: 0] += 1
                    globalToolCounts[cleanName, default: 0] += 1
                    toolCallsTotal += 1
                    if cleanName == "invoke_subagent" {
                        stepSubagents += 1
                        subagentCallsTotal += 1
                    }
                }
            }

            let sortedStepTools = stepToolCounts
                .map { ToolCount(name: $0.key, count: $0.value) }
                .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }

            let thinking = obj["thinking"] as? String ?? ""
            let hasThinking = !thinking.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            var approxGapSec: Double? = nil
            if createdAtMs > 0 && prevStepMs > 0 && createdAtMs >= prevStepMs {
                let delta = Double(createdAtMs - prevStepMs) / 1000.0
                if delta <= 3600.0 {
                    approxGapSec = (delta * 10.0).rounded() / 10.0
                }
            }
            if createdAtMs > 0 {
                prevStepMs = createdAtMs
            }

            let step = StepMetrics(
                stepIndex: stepIndex,
                createdAtMs: createdAtMs,
                approxGapSec: approxGapSec,
                model: effectiveModel,
                modelShort: modelShort,
                family: family,
                inputTokens: inTok,
                cacheReadTokens: cacheTok,
                outputTokens: outTok,
                contextTokens: contextTokens,
                totalTokens: totalTokens,
                cacheHitPct: cacheHitPct,
                costUsd: costUsd,
                savedUsd: savedUsd,
                hasThinking: hasThinking,
                tools: sortedStepTools,
                subagentCalls: stepSubagents
            )
            steps.append(step)

            totalIn += inTok
            totalCache += cacheTok
            totalOut += outTok
            if let c = costUsd {
                totalCost += c
                totalSaved += savedUsd ?? 0
                pricedSteps += 1
            } else {
                unpricedSteps += 1
            }

            var acc = modelAccum[effectiveModel] ?? (
                short: modelShort,
                family: family,
                steps: 0,
                input: 0,
                cache: 0,
                output: 0,
                cost: 0.0,
                saved: 0.0,
                hasPrice: false
            )
            acc.steps += 1
            acc.input += inTok
            acc.cache += cacheTok
            acc.output += outTok
            if let c = costUsd {
                acc.cost += c
                acc.saved += savedUsd ?? 0
                acc.hasPrice = true
            }
            modelAccum[effectiveModel] = acc
        }

        let effectiveLastMs = max(lastMs, fallbackMtimeMs)
        let effectiveFirstMs = firstMs > 0 ? firstMs : effectiveLastMs
        let isActive = (nowMs - effectiveLastMs) <= 120_000 && !steps.isEmpty

        let totalCtx = totalIn + totalCache
        let overallCacheHit = totalCtx > 0
            ? ((Double(totalCache) / Double(totalCtx)) * 1000.0).rounded() / 10.0
            : 0.0

        let totals = ConversationTotals(
            inputTokens: totalIn,
            cacheReadTokens: totalCache,
            outputTokens: totalOut,
            totalTokens: totalCtx + totalOut,
            cacheHitPct: overallCacheHit,
            costUsd: pricedSteps > 0 ? totalCost : nil,
            savedUsd: pricedSteps > 0 ? totalSaved : nil,
            pricedSteps: pricedSteps,
            unpricedSteps: unpricedSteps
        )

        let modelSummaries = modelAccum.map { (key, v) -> ModelSummary in
            let ctx = v.input + v.cache
            let hit = ctx > 0 ? ((Double(v.cache) / Double(ctx)) * 1000.0).rounded() / 10.0 : 0.0
            return ModelSummary(
                model: key,
                modelShort: v.short,
                family: v.family,
                steps: v.steps,
                inputTokens: v.input,
                cacheReadTokens: v.cache,
                outputTokens: v.output,
                totalTokens: ctx + v.output,
                cacheHitPct: hit,
                costUsd: v.hasPrice ? v.cost : nil,
                savedUsd: v.hasPrice ? v.saved : nil
            )
        }.sorted { $0.totalTokens > $1.totalTokens }

        let topTools = globalToolCounts
            .map { ToolCount(name: $0.key, count: $0.value) }
            .sorted { $0.count != $1.count ? $0.count > $1.count : $0.name < $1.name }
            .prefix(16)

        let shortFallbackTitle = "Chat \(conversationId.prefix(8))"

        return ConversationMetrics(
            conversationId: conversationId,
            title: title.isEmpty ? shortFallbackTitle : title,
            firstActivityMs: effectiveFirstMs,
            lastActivityMs: effectiveLastMs,
            isActive: isActive,
            userTurns: userTurns,
            modelStepCount: steps.count,
            toolCallsTotal: toolCallsTotal,
            subagentCallsTotal: subagentCallsTotal,
            totals: totals,
            latestStep: steps.last,
            models: modelSummaries,
            topTools: Array(topTools),
            steps: steps
        )
    }

    func scanAllConversations(nowMs: Int64 = Int64(Date().timeIntervalSince1970 * 1000)) -> (conversations: [ConversationMetrics], signature: String) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(
            at: brainDir,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return ([], "empty")
        }

        var results: [ConversationMetrics] = []
        var sigParts: [String] = []
        var activeKeys = Set<String>()

        for dir in entries {
            let cid = dir.lastPathComponent.lowercased()
            guard TranscriptScanner.isValidUUID(cid) else { continue }

            let transcriptURL = dir
                .appendingPathComponent(".system_generated", isDirectory: true)
                .appendingPathComponent("logs", isDirectory: true)
                .appendingPathComponent("transcript.jsonl", isDirectory: false)

            guard let attrs = try? fm.attributesOfItem(atPath: transcriptURL.path),
                  let fileSize = (attrs[.size] as? NSNumber)?.uint64Value,
                  let modDate = attrs[.modificationDate] as? Date
            else {
                continue
            }

            let mtimeMs = Int64((modDate.timeIntervalSince1970 * 1000.0).rounded())
            let cacheKey = transcriptURL.path
            activeKeys.insert(cacheKey)
            sigParts.append("\(cid):\(mtimeMs):\(fileSize)")

            lock.lock()
            let cached = cache[cacheKey]
            lock.unlock()

            if let c = cached, c.mtimeMs == mtimeMs && c.size == fileSize {
                let freshActive = (nowMs - c.parsed.lastActivityMs) <= 120_000 && c.parsed.modelStepCount > 0
                if freshActive == c.parsed.isActive {
                    results.append(c.parsed)
                } else {
                    let updated = ConversationMetrics(
                        conversationId: c.parsed.conversationId,
                        title: c.parsed.title,
                        firstActivityMs: c.parsed.firstActivityMs,
                        lastActivityMs: c.parsed.lastActivityMs,
                        isActive: freshActive,
                        userTurns: c.parsed.userTurns,
                        modelStepCount: c.parsed.modelStepCount,
                        toolCallsTotal: c.parsed.toolCallsTotal,
                        subagentCallsTotal: c.parsed.subagentCallsTotal,
                        totals: c.parsed.totals,
                        latestStep: c.parsed.latestStep,
                        models: c.parsed.models,
                        topTools: c.parsed.topTools,
                        steps: c.parsed.steps
                    )
                    results.append(updated)
                }
                continue
            }

            guard let data = try? Data(contentsOf: transcriptURL, options: [.mappedIfSafe]),
                  let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
            else {
                continue
            }

            let parsed = parseTranscript(
                text: text,
                conversationId: cid,
                fallbackMtimeMs: mtimeMs,
                nowMs: nowMs
            )

            lock.lock()
            cache[cacheKey] = CacheEntry(mtimeMs: mtimeMs, size: fileSize, parsed: parsed)
            lock.unlock()

            results.append(parsed)
        }

        lock.lock()
        for key in cache.keys where !activeKeys.contains(key) {
            cache.removeValue(forKey: key)
        }
        lock.unlock()

        results.sort { $0.lastActivityMs > $1.lastActivityMs }
        sigParts.sort()
        return (results, sigParts.joined(separator: ";"))
    }

    static func buildHistoryAggregation(
        conversations: [ConversationMetrics],
        range: String,
        now: Date = Date()
    ) -> HistoryAggregation {
        let validRange = ["today", "7d", "30d", "all"].contains(range) ? range : "7d"
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: now)

        let cutoffMs: Int64
        switch validRange {
        case "today":
            cutoffMs = Int64(startOfToday.timeIntervalSince1970 * 1000)
        case "7d":
            let d = cal.date(byAdding: .day, value: -6, to: startOfToday) ?? startOfToday
            cutoffMs = Int64(d.timeIntervalSince1970 * 1000)
        case "30d":
            let d = cal.date(byAdding: .day, value: -29, to: startOfToday) ?? startOfToday
            cutoffMs = Int64(d.timeIntervalSince1970 * 1000)
        default:
            cutoffMs = 0
        }

        var bucketOrder: [String] = []
        var bucketLabels: [String: String] = [:]
        var bucketData: [String: (input: Int64, cache: Int64, output: Int64, steps: Int, cost: Double)] = [:]

        let dayKeyFmt = DateFormatter()
        dayKeyFmt.locale = Locale(identifier: "en_US_POSIX")
        dayKeyFmt.dateFormat = "yyyy-MM-dd"

        let dayLblFmt = DateFormatter()
        dayLblFmt.locale = Locale(identifier: "en_US_POSIX")
        dayLblFmt.dateFormat = "MM/dd"

        if validRange == "today" {
            for hour in 0..<24 {
                let k = String(format: "%02d", hour)
                bucketOrder.append(k)
                bucketLabels[k] = "\(k):00"
                bucketData[k] = (0, 0, 0, 0, 0)
            }
        } else if validRange == "7d" || validRange == "30d" {
            let days = validRange == "7d" ? 7 : 30
            for offset in stride(from: -(days - 1), through: 0, by: 1) {
                if let d = cal.date(byAdding: .day, value: offset, to: startOfToday) {
                    let k = dayKeyFmt.string(from: d)
                    bucketOrder.append(k)
                    bucketLabels[k] = dayLblFmt.string(from: d)
                    bucketData[k] = (0, 0, 0, 0, 0)
                }
            }
        }

        var matchedConvs = Set<String>()
        var totalIn: Int64 = 0
        var totalCache: Int64 = 0
        var totalOut: Int64 = 0
        var totalSteps = 0
        var totalCost = 0.0
        var totalSaved = 0.0
        var pricedSteps = 0

        var modelAccum: [String: (
            short: String,
            family: String,
            steps: Int,
            input: Int64,
            cache: Int64,
            output: Int64,
            cost: Double,
            saved: Double,
            hasPrice: Bool
        )] = [:]

        for conv in conversations {
            for st in conv.steps {
                let ts = st.createdAtMs > 0 ? st.createdAtMs : conv.lastActivityMs
                if cutoffMs > 0 && ts < cutoffMs { continue }

                matchedConvs.insert(conv.conversationId)
                totalSteps += 1
                totalIn += st.inputTokens
                totalCache += st.cacheReadTokens
                totalOut += st.outputTokens
                if let c = st.costUsd {
                    totalCost += c
                    totalSaved += st.savedUsd ?? 0
                    pricedSteps += 1
                }

                var acc = modelAccum[st.model] ?? (
                    short: st.modelShort,
                    family: st.family,
                    steps: 0,
                    input: 0,
                    cache: 0,
                    output: 0,
                    cost: 0,
                    saved: 0,
                    hasPrice: false
                )
                acc.steps += 1
                acc.input += st.inputTokens
                acc.cache += st.cacheReadTokens
                acc.output += st.outputTokens
                if let c = st.costUsd {
                    acc.cost += c
                    acc.saved += st.savedUsd ?? 0
                    acc.hasPrice = true
                }
                modelAccum[st.model] = acc

                let d = Date(timeIntervalSince1970: Double(ts) / 1000.0)
                let bKey: String
                let bLabel: String
                if validRange == "today" {
                    let h = cal.component(.hour, from: d)
                    bKey = String(format: "%02d", h)
                    bLabel = "\(bKey):00"
                } else {
                    bKey = dayKeyFmt.string(from: d)
                    bLabel = dayLblFmt.string(from: d)
                }

                if bucketData[bKey] == nil {
                    bucketOrder.append(bKey)
                    bucketLabels[bKey] = bLabel
                    bucketData[bKey] = (0, 0, 0, 0, 0)
                }
                var b = bucketData[bKey]!
                b.input += st.inputTokens
                b.cache += st.cacheReadTokens
                b.output += st.outputTokens
                b.steps += 1
                b.cost += st.costUsd ?? 0
                bucketData[bKey] = b
            }
        }

        if validRange == "all" {
            bucketOrder.sort()
            if bucketOrder.count > 30 {
                bucketOrder = Array(bucketOrder.suffix(30))
            }
        }

        let series: [TrendBucket] = bucketOrder.compactMap { k in
            guard let b = bucketData[k] else { return nil }
            return TrendBucket(
                key: k,
                label: bucketLabels[k] ?? k,
                inputTokens: b.input,
                cacheReadTokens: b.cache,
                outputTokens: b.output,
                totalTokens: b.input + b.cache + b.output,
                steps: b.steps,
                costUsd: b.cost
            )
        }

        let totalCtx = totalIn + totalCache
        let cacheHitPct = totalCtx > 0
            ? ((Double(totalCache) / Double(totalCtx)) * 1000.0).rounded() / 10.0
            : 0.0

        let models = modelAccum.map { (key, v) -> ModelSummary in
            let ctx = v.input + v.cache
            let hit = ctx > 0 ? ((Double(v.cache) / Double(ctx)) * 1000.0).rounded() / 10.0 : 0.0
            return ModelSummary(
                model: key,
                modelShort: v.short,
                family: v.family,
                steps: v.steps,
                inputTokens: v.input,
                cacheReadTokens: v.cache,
                outputTokens: v.output,
                totalTokens: ctx + v.output,
                cacheHitPct: hit,
                costUsd: v.hasPrice ? v.cost : nil,
                savedUsd: v.hasPrice ? v.saved : nil
            )
        }.sorted { $0.totalTokens > $1.totalTokens }

        return HistoryAggregation(
            range: validRange,
            conversationCount: matchedConvs.count,
            stepCount: totalSteps,
            inputTokens: totalIn,
            cacheReadTokens: totalCache,
            outputTokens: totalOut,
            totalTokens: totalCtx + totalOut,
            cacheHitPct: cacheHitPct,
            costUsd: pricedSteps > 0 ? totalCost : nil,
            savedUsd: pricedSteps > 0 ? totalSaved : nil,
            models: models,
            series: series
        )
    }
}
