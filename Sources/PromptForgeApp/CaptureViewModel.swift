#if os(macOS)
import AppKit
import Combine
import PromptForgeCore

/// Drives the capture window: holds the input, the selected target, and the
/// result, and runs a translation through the Translator.
@MainActor
final class CaptureViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var targets: [Target] = []
    @Published var selectedTarget: Target?
    @Published private(set) var output: String?
    @Published private(set) var isTranslating: Bool = false
    @Published private(set) var errorMessage: String?
    @Published var showingBefore: Bool = false

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        let loadedTargets = environment.availableTargets()
        self.targets = loadedTargets
        let defaultName = environment.settings.defaultTargetName
        self.selectedTarget = loadedTargets.first(where: { $0.name == defaultName }) ?? loadedTargets.first
    }

    var canTranslate: Bool {
        selectedTarget != nil
            && !isTranslating
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Translate the current input for the selected target. On success the
    /// result is shown and auto-copied to the clipboard.
    func translate() {
        guard canTranslate, let target = selectedTarget else { return }
        let raw = inputText
        isTranslating = true
        errorMessage = nil
        output = nil
        showingBefore = false

        Task {
            do {
                let result = try await environment.translator.translate(rawPrompt: raw, target: target)
                output = result
                copyToClipboard(result)
            } catch {
                errorMessage = Self.message(for: error)
            }
            isTranslating = false
        }
    }

    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func message(for error: Error) -> String {
        if let rewrite = error as? RewriteError {
            return rewrite.errorDescription ?? "Translation failed."
        }
        return error.localizedDescription
    }
}
#endif
