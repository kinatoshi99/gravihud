import Foundation

func assertEq<T: Equatable>(_ a: T, _ b: T, _ msg: String) {
    if a != b {
        fputs("FAIL: \(msg) (got \(a), expected \(b))\n", stderr)
        exit(1)
    }
}

func assertTrue(_ cond: Bool, _ msg: String) {
    if !cond {
        fputs("FAIL: \(msg)\n", stderr)
        exit(1)
    }
}

@main
struct TestRunner {
    static func main() {
        // Test 1: Offline pricing, short model names, family inference, unpriced models
        let (cost, saved) = OfflinePricing.estimateCost(
            model: "gemini-2.5-pro",
            inputTokens: 100_000,
            cacheReadTokens: 900_000,
            outputTokens: 50_000
        )
        assertTrue(cost != nil && saved != nil, "Gemini 2.5 Pro should be priced")
        assertTrue(abs((cost ?? 0) - 0.90625) < 0.0001, "Expected cost ~0.90625")
        assertTrue(abs((saved ?? 0) - 0.84375) < 0.0001, "Expected saved ~0.84375")
        assertEq(OfflinePricing.shortName("models/claude-sonnet-4-20250514"), "Claude Sonnet 4", "Short model name")
        assertEq(OfflinePricing.inferFamily("gpt-5-mini"), "openai", "OpenAI family detection")
        let (unpricedCost, unpricedSaved) = OfflinePricing.estimateCost(
            model: "custom-local-model-v1",
            inputTokens: 10_000,
            cacheReadTokens: 5_000,
            outputTokens: 1_000
        )
        assertTrue(unpricedCost == nil && unpricedSaved == nil, "Unknown model should be unpriced")
        print("PASS [1/8] Offline pricing, model formatting & unpriced handling")

        // Test 2: Transcript parsing + torn trailing line tolerance + <USER_REQUEST> title extraction (EN & TH)
        let sampleJSONL = """
        {"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","created_at":"2026-11-20T10:00:00+07:00","content":"<USER_REQUEST>\\nBuild offline floating HUD ทดสอบภาษาไทย\\n</USER_REQUEST>"}
        {"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","created_at":"2026-11-20T10:00:05.500+07:00","model":"gemini-3-pro","input_tokens":20000,"cache_read_tokens":80000,"output_tokens":1500,"thinking":"step by step","tool_calls":[{"name":"read_file"},{"name":"read_file"},{"name":"invoke_subagent"}]}
        {"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","created_at":"2026-11-20T10:00:12+07:00","model":"claude-sonnet-4","input_tokens":5000,"cache_read_tokens":95000,"output_tokens":500}
        {"step_index":3,"source":"MODEL","broken_incomplete_json
        """
        let scanner = TranscriptScanner()
        let parsed = scanner.parseTranscript(
            text: sampleJSONL,
            conversationId: "11111111-2222-3333-4444-555555555555",
            fallbackMtimeMs: 1_795_000_000_000,
            nowMs: 1_795_000_010_000
        )
        assertEq(parsed.title, "Build offline floating HUD ทดสอบภาษาไทย", "Bilingual <USER_REQUEST> title extraction")
        assertEq(parsed.userTurns, 1, "User turns")
        assertEq(parsed.modelStepCount, 2, "Should ignore torn line and parse 2 valid steps")
        assertEq(parsed.totals.inputTokens, 25_000, "Total input tokens")
        assertEq(parsed.totals.cacheReadTokens, 175_000, "Total cache read tokens")
        assertEq(parsed.totals.outputTokens, 2_000, "Total output tokens")
        assertEq(parsed.totals.totalTokens, 202_000, "Total tokens")
        assertEq(parsed.totals.cacheHitPct, 87.5, "Cache hit percentage")
        assertEq(parsed.subagentCallsTotal, 1, "Subagent call count")
        assertEq(parsed.topTools.first?.name, "read_file", "Top tool")
        assertEq(parsed.topTools.first?.count, 2, "Top tool count")
        assertTrue(parsed.steps[0].hasThinking, "Thinking flag")
        assertEq(parsed.steps[1].approxGapSec, 6.5, "Approx gap seconds")
        print("PASS [2/8] Transcript parsing, UTF-8 Thai title & torn line recovery")

        // Test 3: Multi-model breakdown ordering
        assertEq(parsed.models.count, 2, "Should track both Gemini 3 Pro and Claude Sonnet 4")
        assertEq(parsed.models[0].modelShort, "Gemini 3 Pro", "Highest-token model first")
        assertEq(parsed.models[1].modelShort, "Claude Sonnet 4", "Second model next")
        print("PASS [3/8] Multi-model summary breakdown")

        // Test 4: History aggregation across all ranges (today, 7d, 30d, all)
        let refNow = ISO8601DateFormatter().date(from: "2026-11-20T12:00:00+07:00")!
        for range in ["today", "7d", "30d", "all"] {
            let hist = TranscriptScanner.buildHistoryAggregation(conversations: [parsed], range: range, now: refNow)
            assertEq(hist.range, range, "History range matches \(range)")
            assertEq(hist.conversationCount, 1, "History conversation count for \(range)")
            assertEq(hist.stepCount, 2, "History step count for \(range)")
            assertEq(hist.totalTokens, 202_000, "History total tokens for \(range)")
            assertTrue(!hist.series.isEmpty, "History series non-empty for \(range)")
        }
        print("PASS [4/8] History aggregation across today/7d/30d/all")

        // Test 5: SettingsStore validation, persistence & corrupt JSON recovery
        let tmpSettingsDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("gravihud-settings-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpSettingsDir) }
        let store = SettingsStore(directory: tmpSettingsDir)
        let patched = store.applyPatch([
            "language": "th",
            "dockSide": "left",
            "onlyWhenAntigravityActive": false,
            "contextRefLimit": 512_000,
            "fontScale": "invalid_fallback",
        ], to: store.load())
        assertEq(patched.language, "th", "Saved language")
        assertEq(patched.dockSide, "left", "Saved dockSide")
        assertEq(patched.onlyWhenAntigravityActive, false, "Saved onlyWhenAntigravityActive")
        assertEq(patched.contextRefLimit, 512_000, "Saved contextRefLimit")
        assertEq(patched.fontScale, "md", "Invalid fontScale falls back to md")
        assertEq(store.load(), patched, "Settings round-trip")
        // Corrupt file should recover safely to defaults without crashing
        try! "{not valid json".write(to: store.settingsURL, atomically: true, encoding: .utf8)
        let recovered = store.load()
        assertEq(recovered.fontScale, "md", "Corrupt settings JSON falls back safely")
        print("PASS [5/8] SettingsStore validation, persistence & corrupt recovery")

        // Test 6: Synthetic directory scan + strict UUID filtering + mtime/size cache
        let tmpAppData = FileManager.default.temporaryDirectory
            .appendingPathComponent("gravihud-brain-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: tmpAppData) }

        let validUUID = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        let logsDir = tmpAppData
            .appendingPathComponent("brain", isDirectory: true)
            .appendingPathComponent(validUUID, isDirectory: true)
            .appendingPathComponent(".system_generated", isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
        let invalidDir = tmpAppData
            .appendingPathComponent("brain", isDirectory: true)
            .appendingPathComponent("not-a-uuid", isDirectory: true)

        try! FileManager.default.createDirectory(at: logsDir, withIntermediateDirectories: true)
        try! FileManager.default.createDirectory(at: invalidDir, withIntermediateDirectories: true)
        let transcriptFile = logsDir.appendingPathComponent("transcript.jsonl")
        try! sampleJSONL.write(to: transcriptFile, atomically: true, encoding: .utf8)

        let dirScanner = TranscriptScanner(appDataDir: tmpAppData)
        let (firstScan, sig1) = dirScanner.scanAllConversations()
        assertEq(firstScan.count, 1, "Should scan 1 valid UUID conversation and ignore invalid dirs")
        assertEq(firstScan[0].conversationId, validUUID, "Matched conversation ID")
        assertEq(firstScan[0].totals.totalTokens, 202_000, "Matched total tokens")

        let (secondScan, sig2) = dirScanner.scanAllConversations()
        assertEq(sig1, sig2, "Unchanged directory produces identical signature")
        assertEq(secondScan.count, 1, "Cached scan returns same conversation")
        print("PASS [6/8] Directory scan, UUID filtering & mtime/size cache")

        // Test 7: Cache invalidation on transcript append & deletion
        let appended = sampleJSONL + "\n" + #"{"step_index":3,"source":"MODEL","type":"PLANNER_RESPONSE","created_at":"2026-11-20T10:00:20+07:00","model":"gemini-3-pro","input_tokens":1000,"cache_read_tokens":9000,"output_tokens":500}"#
        try! appended.write(to: transcriptFile, atomically: true, encoding: .utf8)
        let (thirdScan, sig3) = dirScanner.scanAllConversations()
        assertTrue(sig3 != sig2, "Appending transcript changes signature")
        assertEq(thirdScan[0].modelStepCount, 3, "Appended step parsed cleanly")
        assertEq(thirdScan[0].totals.totalTokens, 212_500, "Updated token sum")

        try! FileManager.default.removeItem(at: transcriptFile)
        let (fourthScan, _) = dirScanner.scanAllConversations()
        assertEq(fourthScan.count, 0, "Deleted transcript pruned from scan")
        print("PASS [7/8] Cache invalidation on append & deletion")

        // Test 8: Empty / zero-token transcript graceful handling
        let emptyParsed = scanner.parseTranscript(
            text: "",
            conversationId: "99999999-8888-7777-6666-555555555555",
            fallbackMtimeMs: 1_795_000_000_000
        )
        assertEq(emptyParsed.modelStepCount, 0, "Empty transcript has 0 steps")
        assertEq(emptyParsed.totals.totalTokens, 0, "Empty transcript has 0 tokens")
        assertEq(emptyParsed.title, "Chat 99999999", "Fallback title uses short UUID")
        print("PASS [8/8] Empty transcript graceful handling")
    }
}
