#if os(macOS)
import Foundation
import Combine
import PromptForgeCore

/// The composition root: the one place the concrete stores and the active engine
/// are built and wired into a Translator.
///
/// This is the only unit that picks a concrete engine. Everything above it holds
/// the Translator, which holds the engine through the `RewriteEngine` protocol.
@MainActor
final class AppEnvironment: ObservableObject {
    let styleGuides: StyleGuideStore
    let history: HistoryStore
    let secrets: KeychainSecretStore
    let settingsStore: SettingsStore
    let translator: Translator

    @Published private(set) var settings: Settings

    init() throws {
        self.styleGuides = try StyleGuideStore(directory: try StyleGuideStore.defaultDirectory())
        self.history = HistoryStore(fileURL: try HistoryStore.defaultFileURL())
        self.secrets = KeychainSecretStore()
        self.settingsStore = SettingsStore(fileURL: try SettingsStore.defaultFileURL())

        let loaded = settingsStore.load()
        self.settings = loaded
        self.translator = Translator(
            guides: styleGuides,
            engine: AppEnvironment.makeEngine(from: loaded, secrets: secrets),
            history: history
        )
    }

    /// The targets that have a guide on disk.
    func availableTargets() -> [Target] {
        (try? styleGuides.availableTargets()) ?? []
    }

    /// Apply new settings: persist them and rebuild the active engine so the
    /// Translator uses the current choice.
    func update(settings newSettings: Settings) {
        settings = newSettings
        try? settingsStore.save(newSettings)
        translator.engine = AppEnvironment.makeEngine(from: newSettings, secrets: secrets)
    }

    /// Build the active engine from settings. The one place a concrete engine is
    /// chosen.
    static func makeEngine(from settings: Settings, secrets: SecretStore) -> RewriteEngine {
        switch settings.activeEngine {
        case .cloud:
            return CloudEngine(secretStore: secrets, model: settings.cloudModel)
        case .local:
            return LocalEngine(model: settings.localModel)
        }
    }
}
#endif
