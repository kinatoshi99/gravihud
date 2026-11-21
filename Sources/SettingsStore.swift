import Foundation

/// Persists ONLY UI preferences inside `~/Library/Application Support/GraviHUD/settings.json`.
/// Never writes to Antigravity's config directory or anywhere outside its own Application Support folder.
final class SettingsStore {
    let settingsURL: URL

    private static let allowedLanguages: Set<String> = ["th", "en"]
    private static let allowedFontScales: Set<String> = ["sm", "md", "lg"]
    private static let allowedAccents: Set<String> = ["host", "blue", "emerald", "violet", "amber"]
    private static let allowedModelModes: Set<String> = ["short", "full"]
    private static let allowedContextLimits: Set<Int64> = [200_000, 256_000, 512_000, 1_000_000]
    private static let allowedStepOrders: Set<String> = ["newest", "oldest"]
    private static let allowedDockSides: Set<String> = ["right", "left"]

    init(directory: URL? = nil) {
        let baseDir: URL
        if let dir = directory {
            baseDir = dir
        } else {
            let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
                ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support", isDirectory: true)
            baseDir = appSupport.appendingPathComponent("GraviHUD", isDirectory: true)
        }
        self.settingsURL = baseDir.appendingPathComponent("settings.json", isDirectory: false)
    }

    func normalize(_ s: AppSettings) -> AppSettings {
        var clean = AppSettings()
        clean.language = SettingsStore.allowedLanguages.contains(s.language) ? s.language : AppSettings.defaultLanguage()
        clean.fontScale = SettingsStore.allowedFontScales.contains(s.fontScale) ? s.fontScale : "md"
        clean.accent = SettingsStore.allowedAccents.contains(s.accent) ? s.accent : "host"
        clean.modelNameMode = SettingsStore.allowedModelModes.contains(s.modelNameMode) ? s.modelNameMode : "short"
        clean.contextRefLimit = SettingsStore.allowedContextLimits.contains(s.contextRefLimit) ? s.contextRefLimit : 256_000
        clean.stepOrder = SettingsStore.allowedStepOrders.contains(s.stepOrder) ? s.stepOrder : "newest"
        clean.onlyWhenAntigravityActive = s.onlyWhenAntigravityActive
        clean.dockSide = SettingsStore.allowedDockSides.contains(s.dockSide) ? s.dockSide : "right"
        clean.collapsed = s.collapsed
        clean.verticalRatio = min(0.95, max(0.05, s.verticalRatio.isFinite ? s.verticalRatio : 0.85))
        return clean
    }

    func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }
        return normalize(decoded)
    }

    @discardableResult
    func save(_ next: AppSettings) -> AppSettings {
        let clean = normalize(next)
        let dir = settingsURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true, attributes: nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(clean) {
            try? data.write(to: settingsURL, options: [.atomic])
        }
        return clean
    }

    @discardableResult
    func applyPatch(_ patch: [String: Any], to current: AppSettings) -> AppSettings {
        var next = current
        if let v = patch["language"] as? String { next.language = v }
        if let v = patch["fontScale"] as? String { next.fontScale = v }
        if let v = patch["accent"] as? String { next.accent = v }
        if let v = patch["modelNameMode"] as? String { next.modelNameMode = v }
        if let v = patch["contextRefLimit"] as? NSNumber { next.contextRefLimit = v.int64Value }
        if let v = patch["stepOrder"] as? String { next.stepOrder = v }
        if let v = patch["onlyWhenAntigravityActive"] as? Bool { next.onlyWhenAntigravityActive = v }
        if let v = patch["dockSide"] as? String { next.dockSide = v }
        if let v = patch["collapsed"] as? Bool { next.collapsed = v }
        if let v = patch["verticalRatio"] as? NSNumber { next.verticalRatio = v.doubleValue }
        return save(next)
    }

    @discardableResult
    func reset() -> AppSettings {
        return save(AppSettings())
    }
}
