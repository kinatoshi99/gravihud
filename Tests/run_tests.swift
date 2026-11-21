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
        // Test 1: Offline pricing & short model name formatting
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
        print("PASS [1/5] Offline pricing & short model names")

        // Test 2: Transcript parsing + torn trailing line tolerance + <USER_REQUEST> title extraction
        let sampleJSONL = """
        {"step_index":0,"source":"USER_EXPLICIT","type":"USER_INPUT","created_at":"2026-11-20T10:00:00+07:00","content":"<USER_REQUEST>\\nBuild offline floating HUD\\n</USER_REQUEST>"}
        {"step_index":1,"source":"MODEL","type":"PLANNER_RESPONSE","created_at":"2026-11-20T10:00:05.500+07:00","model":"gemini-3-pro","input_tokens":20000,"cache_read_tokens":80000,"output_tokens":1500,"thinking":"step by step","tool_calls":[{"name":"read_file"},{"name":"read_file"},{"name":"invoke_subagent"}]}
        {"step_index":2,"source":"MODEL","type":"PLANNER_RESPONSE","created_at":"2026-11-20T10:00:12+07:00","model":"gemini-3-pro","input_tokens":5000,"cache_read_tokens":95000,"output_tokens":500}
        {"step_index":3,"source":"MODEL","broken_incomplete_json
        """
        let scanner = TranscriptScanner()
        let parsed = scanner.parseTranscript(
            text: sampleJSONL,
            conversationId: "11111111-2222-3333-4444-555555555555",
            fallbackMtimeMs: 1_795_000_000_000,
            nowMs: 1_795_000_010_000
        )
        assertEq(parsed.title, "Build offline floating HUD", "<USER_REQUEST> title extraction")
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
        print("PASS [2/5] Transcript parsing & torn line recovery")

        // Test 3: History aggregation
        let histAll = TranscriptScanner.buildHistoryAggregation(conversations: [parsed], range: "all")
        assertEq(histAll.conversationCount, 1, "History conversation count")
        assertEq(histAll.stepCount, 2, "History step count")
        assertEq(histAll.totalTokens, 202_000, "History total tokens")
        assertTrue(!histAll.series.isEmpty, "History series non-empty")
        print("PASS [3/5] History aggregation")

        // Test 4: SettingsStore normalization & persistence
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
        print("PASS [4/5] SettingsStore validation & persistence")

        // Test 5: End-to-end synthetic directory scan + mtime/size cache + non-UUID ignore
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
        try! sampleJSONL.write(
            to: logsDir.appendingPathComponent("transcript.jsonl"),
            atomically: true,
            encoding: .utf8
        )

        let dirScanner = TranscriptScanner(appDataDir: tmpAppData)
        let (firstScan, sig1) = dirScanner.scanAllConversations()
        assertEq(firstScan.count, 1, "Should scan 1 valid UUID conversation and ignore invalid dirs")
        assertEq(firstScan[0].conversationId, validUUID, "Matched conversation ID")
        assertEq(firstScan[0].totals.totalTokens, 202_000, "Matched total tokens")

        let (secondScan, sig2) = dirScanner.scanAllConversations()
        assertEq(sig1, sig2, "Unchanged directory should produce identical signature")
        assertEq(secondScan.count, 1, "Cached scan should return same conversation")
        print("PASS [5/5] Directory scan, UUID filtering & mtime/size cache")
    }
}
