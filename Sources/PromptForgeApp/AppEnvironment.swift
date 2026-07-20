#if os(macOS)
import Foundation
import Combine
import PromptForgeCore

/// The composition root: the one place the concrete stores and the active engine
/// are built and wired into a Translator.
///
/// This app runs fully on-device: the engine is always the local Ollama engine.
/// The core library still ships a cloud engine behind the same `RewriteEngine`
/// protocol, but PromptForge does not use it, so nothing here can reach an
/// external API.
@MainActor
final class AppEnvironment: ObservableObject {
    let styleGuides: StyleGuideStore
    let history: HistoryStore
    let settingsStore: SettingsStore
    let translator: Translator

    @Published private(set) var settings: Settings

    init() throws {
        self.styleGuides = try StyleGuideStore(directory: try StyleGuideStore.defaultDirectory())
        self.history = HistoryStore(fileURL: try HistoryStore.defaultFileURL())
        self.settingsStore = SettingsStore(fileURL: try SettingsStore.defaultFileURL())

        let loaded = settingsStore.load()
        self.settings = loaded
        self.translator = Translator(
            guides: styleGuides,
            engine: AppEnvironment.makeEngine(from: loaded),
            history: history
        )
    }

    /// The targets that have a guide on disk.
    func availableTargets() -> [Target] {
        (try? styleGuides.availableTargets()) ?? []
    }

    /// Apply new settings: persist them and rebuild the local engine so a model
    /// change takes effect.
    func update(settings newSettings: Settings) {
        settings = newSettings
        try? settingsStore.save(newSettings)
        translator.engine = AppEnvironment.makeEngine(from: newSettings)
    }

    /// Build the engine. PromptForge is local-only, so this is always the Ollama
    /// engine using the configured model tag.
    static func makeEngine(from settings: Settings) -> RewriteEngine {
        LocalEngine(model: settings.localModel)
    }
}
#endif
