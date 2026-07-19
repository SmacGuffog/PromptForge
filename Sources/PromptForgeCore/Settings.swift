import Foundation

/// How the app should follow light and dark appearance.
public enum Theme: String, Codable, Hashable, Sendable, CaseIterable {
    case system
    case light
    case dark
}

/// The global hotkey that summons the capture window.
///
/// Stored as a logical key name plus modifiers so the value is portable and
/// diffs cleanly. The UI layer maps this to a real registration; the core does
/// not depend on any Mac hotkey API.
public struct Hotkey: Codable, Hashable, Sendable {
    public enum Modifier: String, Codable, Hashable, Sendable, CaseIterable {
        case command
        case option
        case control
        case shift
    }

    /// Logical key name, for example "space" or "p".
    public var key: String

    /// The modifier keys held with `key`.
    public var modifiers: [Modifier]

    public init(key: String, modifiers: [Modifier]) {
        self.key = key
        self.modifiers = modifiers
    }

    /// A conflict-light default: control plus option plus space. The user can
    /// change it in settings.
    public static let `default` = Hotkey(key: "space", modifiers: [.control, .option])
}

/// User-configurable settings, persisted as one small JSON file.
///
/// Decoding fills any missing field with its default, so a settings file
/// written by an older build, or a hand-edited partial file, still loads.
public struct Settings: Codable, Equatable, Sendable {
    /// Which engine performs rewrites: cloud or local.
    public var activeEngine: EngineKind

    /// The Anthropic model id used by the cloud engine.
    public var cloudModel: String

    /// The Ollama model tag used by the local engine.
    public var localModel: String

    /// The global capture hotkey.
    public var hotkey: Hotkey

    /// The target selected by default in the capture window.
    public var defaultTargetName: String

    /// Light and dark appearance handling.
    public var theme: Theme

    /// Default Anthropic model for the cloud engine: Claude Haiku 4.5.
    public static let defaultCloudModel = "claude-haiku-4-5"

    /// Default Ollama model tag for the local engine: Qwen 2.5 7B.
    public static let defaultLocalModel = "qwen2.5:7b"

    public init(
        activeEngine: EngineKind = .cloud,
        cloudModel: String = Settings.defaultCloudModel,
        localModel: String = Settings.defaultLocalModel,
        hotkey: Hotkey = .default,
        defaultTargetName: String = "Claude",
        theme: Theme = .system
    ) {
        self.activeEngine = activeEngine
        self.cloudModel = cloudModel
        self.localModel = localModel
        self.hotkey = hotkey
        self.defaultTargetName = defaultTargetName
        self.theme = theme
    }

    private enum CodingKeys: String, CodingKey {
        case activeEngine
        case cloudModel
        case localModel
        case hotkey
        case defaultTargetName
        case theme
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.activeEngine = try container.decodeIfPresent(EngineKind.self, forKey: .activeEngine) ?? .cloud
        self.cloudModel = try container.decodeIfPresent(String.self, forKey: .cloudModel) ?? Settings.defaultCloudModel
        self.localModel = try container.decodeIfPresent(String.self, forKey: .localModel) ?? Settings.defaultLocalModel
        self.hotkey = try container.decodeIfPresent(Hotkey.self, forKey: .hotkey) ?? .default
        self.defaultTargetName = try container.decodeIfPresent(String.self, forKey: .defaultTargetName) ?? "Claude"
        self.theme = try container.decodeIfPresent(Theme.self, forKey: .theme) ?? .system
    }
}

/// Loads and saves `Settings` as a JSON file on disk.
///
/// Loading never throws: a missing or unreadable file yields default settings,
/// so the app always starts in a usable state. Saving writes atomically and
/// creates the containing folder if needed.
public final class SettingsStore {
    private let fileURL: URL
    private let fileManager: FileManager

    public init(fileURL: URL, fileManager: FileManager = .default) {
        self.fileURL = fileURL
        self.fileManager = fileManager
    }

    /// The default settings file:
    /// `~/Library/Application Support/PromptForge/settings.json`, a sibling of
    /// the guides and history.
    public static func defaultFileURL(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport
            .appendingPathComponent("PromptForge", isDirectory: true)
            .appendingPathComponent("settings.json")
    }

    /// Load settings, returning defaults when the file is absent or unreadable.
    public func load() -> Settings {
        guard let data = try? Data(contentsOf: fileURL),
              let settings = try? JSONDecoder().decode(Settings.self, from: data)
        else {
            return Settings()
        }
        return settings
    }

    /// Save settings, creating the containing folder if needed.
    public func save(_ settings: Settings) throws {
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: fileURL, options: .atomic)
    }
}
