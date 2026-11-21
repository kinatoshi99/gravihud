import Foundation

/// Static offline reference API rates (USD per 1M tokens).
/// Reference estimates only — never fetched from the network and never represents real account quota.
struct PriceEntry {
    let pattern: NSRegularExpression
    let inputPerMillion: Double
    let cacheReadPerMillion: Double
    let outputPerMillion: Double
    let label: String

    init(pattern: String, input: Double, cacheRead: Double, output: Double, label: String) {
        self.pattern = try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        self.inputPerMillion = input
        self.cacheReadPerMillion = cacheRead
        self.outputPerMillion = output
        self.label = label
    }
}

enum OfflinePricing {
    static let entries: [PriceEntry] = [
        PriceEntry(pattern: "gemini[-_ ]?2\\.5[-_ ]?pro", input: 1.25, cacheRead: 0.3125, output: 10.00, label: "Gemini 2.5 Pro"),
        PriceEntry(pattern: "gemini[-_ ]?2\\.5[-_ ]?flash[-_ ]?lite", input: 0.10, cacheRead: 0.025, output: 0.40, label: "Gemini 2.5 Flash-Lite"),
        PriceEntry(pattern: "gemini[-_ ]?2\\.5[-_ ]?flash", input: 0.30, cacheRead: 0.075, output: 2.50, label: "Gemini 2.5 Flash"),
        PriceEntry(pattern: "gemini[-_ ]?3(?:\\.\\d+)?[-_ ]?pro", input: 2.00, cacheRead: 0.20, output: 12.00, label: "Gemini 3 Pro"),
        PriceEntry(pattern: "gemini[-_ ]?3(?:\\.\\d+)?[-_ ]?flash[-_ ]?lite", input: 0.10, cacheRead: 0.025, output: 0.40, label: "Gemini 3 Flash-Lite"),
        PriceEntry(pattern: "gemini[-_ ]?3(?:\\.\\d+)?[-_ ]?flash", input: 0.50, cacheRead: 0.05, output: 3.00, label: "Gemini 3 Flash"),
        PriceEntry(pattern: "gemini[-_ ]?2\\.0[-_ ]?flash", input: 0.10, cacheRead: 0.025, output: 0.40, label: "Gemini 2.0 Flash"),
        PriceEntry(pattern: "claude[-_ ]?(?:opus[-_ ]?4(?:[.-]\\d+)?|4(?:[.-]\\d+)?[-_ ]?opus)", input: 15.00, cacheRead: 1.50, output: 75.00, label: "Claude Opus 4"),
        PriceEntry(pattern: "claude[-_ ]?(?:sonnet[-_ ]?4(?:[.-]\\d+)?|4(?:[.-]\\d+)?[-_ ]?sonnet)", input: 3.00, cacheRead: 0.30, output: 15.00, label: "Claude Sonnet 4"),
        PriceEntry(pattern: "claude[-_ ]?(?:haiku[-_ ]?4(?:[.-]\\d+)?|3[-_ .]?5[-_ ]?haiku)", input: 0.80, cacheRead: 0.08, output: 4.00, label: "Claude Haiku"),
        PriceEntry(pattern: "claude[-_ ]?3[-_ .]?7[-_ ]?sonnet|claude[-_ ]?3[-_ .]?5[-_ ]?sonnet", input: 3.00, cacheRead: 0.30, output: 15.00, label: "Claude Sonnet"),
        PriceEntry(pattern: "gpt[-_ ]?5(?:\\.\\d+)?[-_ ]?mini", input: 0.25, cacheRead: 0.025, output: 2.00, label: "GPT-5 mini"),
        PriceEntry(pattern: "gpt[-_ ]?5(?:\\.\\d+)?", input: 1.25, cacheRead: 0.125, output: 10.00, label: "GPT-5"),
        PriceEntry(pattern: "gpt[-_ ]?4o[-_ ]?mini", input: 0.15, cacheRead: 0.075, output: 0.60, label: "GPT-4o mini"),
        PriceEntry(pattern: "gpt[-_ ]?4o", input: 2.50, cacheRead: 1.25, output: 10.00, label: "GPT-4o"),
        PriceEntry(pattern: "o3[-_ ]?mini|o4[-_ ]?mini", input: 1.10, cacheRead: 0.275, output: 4.40, label: "o-series mini"),
        PriceEntry(pattern: "gpt[-_ ]?oss", input: 0.20, cacheRead: 0.05, output: 0.60, label: "GPT-OSS"),
    ]

    static func lookup(_ rawModel: String) -> PriceEntry? {
        let trimmed = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        for entry in entries {
            if entry.pattern.firstMatch(in: trimmed, options: [], range: range) != nil {
                return entry
            }
        }
        return nil
    }

    static func inferFamily(_ rawModel: String) -> String {
        let lower = rawModel.lowercased()
        if lower.contains("gemini") { return "gemini" }
        if lower.contains("claude") { return "claude" }
        if lower.contains("gpt") || lower.hasPrefix("o1") || lower.hasPrefix("o3") || lower.hasPrefix("o4") {
            return "openai"
        }
        return "other"
    }

    static func shortName(_ rawModel: String) -> String {
        let trimmed = rawModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Unknown" }

        var cleaned = trimmed
        if let lastSlash = cleaned.lastIndex(of: "/") {
            cleaned = String(cleaned[cleaned.index(after: lastSlash)...])
        }
        for prefix in ["MODEL_PLACEHOLDER_", "MODEL_GOOGLE_", "MODEL_ANTHROPIC_", "MODEL_OPENAI_", "MODEL_"] {
            if cleaned.uppercased().hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                break
            }
        }
        cleaned = cleaned.replacingOccurrences(of: #"-\d{8}$"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"-preview-\d{2}-\d{2}$"#, with: "", options: .regularExpression)

        if let matched = lookup(trimmed) {
            return matched.label
        }

        let words = cleaned
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .split(separator: " ")
            .map { part -> String in
                let s = String(part)
                if s.lowercased() == "gpt" { return "GPT" }
                if s.lowercased() == "oss" { return "OSS" }
                if s.first?.isNumber == true { return s }
                return s.prefix(1).uppercased() + s.dropFirst().lowercased()
            }
        let joined = words.joined(separator: " ")
        return joined.isEmpty ? trimmed : joined
    }

    static func estimateCost(
        model: String,
        inputTokens: Int64,
        cacheReadTokens: Int64,
        outputTokens: Int64
    ) -> (costUsd: Double?, savedUsd: Double?) {
        guard let rate = lookup(model) else {
            return (nil, nil)
        }
        let inTok = max(0, Double(inputTokens))
        let cacheTok = max(0, Double(cacheReadTokens))
        let outTok = max(0, Double(outputTokens))

        let cost =
            (inTok * rate.inputPerMillion +
             cacheTok * rate.cacheReadPerMillion +
             outTok * rate.outputPerMillion) / 1_000_000.0
        let saved =
            max(0.0, (cacheTok * (rate.inputPerMillion - rate.cacheReadPerMillion)) / 1_000_000.0)
        return (cost, saved)
    }
}
