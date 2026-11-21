import Foundation

struct ToolCount: Codable, Equatable {
    let name: String
    let count: Int
}

struct StepMetrics: Codable {
    let stepIndex: Int
    let createdAtMs: Int64
    let approxGapSec: Double?
    let model: String
    let modelShort: String
    let family: String
    let inputTokens: Int64
    let cacheReadTokens: Int64
    let outputTokens: Int64
    let contextTokens: Int64
    let totalTokens: Int64
    let cacheHitPct: Double
    let costUsd: Double?
    let savedUsd: Double?
    let hasThinking: Bool
    let tools: [ToolCount]
    let subagentCalls: Int
}

struct ConversationTotals: Codable {
    let inputTokens: Int64
    let cacheReadTokens: Int64
    let outputTokens: Int64
    let totalTokens: Int64
    let cacheHitPct: Double
    let costUsd: Double?
    let savedUsd: Double?
    let pricedSteps: Int
    let unpricedSteps: Int
}

struct ModelSummary: Codable {
    let model: String
    let modelShort: String
    let family: String
    let steps: Int
    let inputTokens: Int64
    let cacheReadTokens: Int64
    let outputTokens: Int64
    let totalTokens: Int64
    let cacheHitPct: Double
    let costUsd: Double?
    let savedUsd: Double?
}

struct ConversationMetrics: Codable {
    let conversationId: String
    let title: String
    let firstActivityMs: Int64
    let lastActivityMs: Int64
    let isActive: Bool
    let userTurns: Int
    let modelStepCount: Int
    let toolCallsTotal: Int
    let subagentCallsTotal: Int
    let totals: ConversationTotals
    let latestStep: StepMetrics?
    let models: [ModelSummary]
    let topTools: [ToolCount]
    let steps: [StepMetrics]
}

struct ConversationListItem: Codable {
    let conversationId: String
    let title: String
    let lastActivityMs: Int64
    let isActive: Bool
    let modelStepCount: Int
    let totalTokens: Int64
    let costUsd: Double?
    let latestModelShort: String
}

struct TrendBucket: Codable {
    let key: String
    let label: String
    let inputTokens: Int64
    let cacheReadTokens: Int64
    let outputTokens: Int64
    let totalTokens: Int64
    let steps: Int
    let costUsd: Double
}

struct HistoryAggregation: Codable {
    let range: String
    let conversationCount: Int
    let stepCount: Int
    let inputTokens: Int64
    let cacheReadTokens: Int64
    let outputTokens: Int64
    let totalTokens: Int64
    let cacheHitPct: Double
    let costUsd: Double?
    let savedUsd: Double?
    let models: [ModelSummary]
    let series: [TrendBucket]
}

struct AppSettings: Codable, Equatable {
    var language: String = AppSettings.defaultLanguage()
    var fontScale: String = "md"
    var accent: String = "host"
    var modelNameMode: String = "short"
    var contextRefLimit: Int64 = 256_000
    var stepOrder: String = "newest"
    var onlyWhenAntigravityActive: Bool = true
    var dockSide: String = "right"
    var collapsed: Bool = false
    var verticalRatio: Double = 0.85

    static func defaultLanguage() -> String {
        if let first = Locale.preferredLanguages.first?.lowercased(), first.hasPrefix("th") {
            return "th"
        }
        return "en"
    }
}

struct TelemetryMeta: Codable {
    let offlineOnly: Bool
    let zeroPorts: Bool
    let brainDir: String
    let settingsFile: String
    let scannedConversations: Int
    let pricingEntries: Int
    let autoFollowingLatest: Bool
    let antigravityRunning: Bool
}

struct TelemetryPayload: Codable {
    let generatedAtMs: Int64
    let settings: AppSettings
    let meta: TelemetryMeta
    let selectedConvMode: String
    let activeConversation: ConversationMetrics?
    let conversations: [ConversationListItem]
    let history: HistoryAggregation
}
