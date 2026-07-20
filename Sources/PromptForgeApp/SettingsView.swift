#if os(macOS)
import Combine
import SwiftUI
import PromptForgeCore

/// Backs the Settings pane: edits a draft `Settings` and applies changes through
/// the composition root (persist plus rebuild the engine), and manages the
/// optional Anthropic API key in the Keychain.
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var draft: PromptForgeCore.Settings
    @Published var apiKeyInput: String = ""
    @Published private(set) var hasStoredKey: Bool = false
    @Published private(set) var keyStatus: String?

    let targets: [Target]
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.draft = environment.settings
        self.targets = environment.availableTargets()
        self.hasStoredKey = ((try? environment.secrets.apiKey()) ?? nil)?.isEmpty == false
    }

    /// Apply the current draft: persist it and rebuild the active engine.
    func apply() {
        environment.update(settings: draft)
    }

    func saveAPIKey() {
        do {
            try environment.secrets.setAPIKey(apiKeyInput)
            hasStoredKey = true
            apiKeyInput = ""
            keyStatus = "Key saved to the Keychain."
        } catch {
            keyStatus = "Could not save the key: \(error.localizedDescription)"
        }
    }

    func removeAPIKey() {
        try? environment.secrets.deleteAPIKey()
        hasStoredKey = false
        keyStatus = "Key removed."
    }

    func modifierBinding(_ modifier: Hotkey.Modifier) -> Binding<Bool> {
        Binding(
            get: { self.draft.hotkey.modifiers.contains(modifier) },
            set: { isOn in
                var set = Set(self.draft.hotkey.modifiers)
                if isOn { set.insert(modifier) } else { set.remove(modifier) }
                // Keep a stable order for readable persistence.
                self.draft.hotkey.modifiers = Hotkey.Modifier.allCases.filter { set.contains($0) }
            }
        )
    }
}

/// The settings pane. Fully local by default; the Anthropic key is optional and
/// only needed if the cloud engine is selected.
struct SettingsView: View {
    @StateObject private var model: SettingsViewModel

    private let keyChoices: [String] = ["space"] + "abcdefghijklmnopqrstuvwxyz".map { String($0) }

    init(environment: AppEnvironment) {
        _model = StateObject(wrappedValue: SettingsViewModel(environment: environment))
    }

    var body: some View {
        Form {
            Section("Engine") {
                Picker("Rewrite with", selection: $model.draft.activeEngine) {
                    Text("Local (Ollama)").tag(EngineKind.local)
                    Text("Cloud (Anthropic)").tag(EngineKind.cloud)
                }
                TextField("Local model", text: $model.draft.localModel)
                TextField("Cloud model", text: $model.draft.cloudModel)
            }

            Section("Capture") {
                Picker("Default target", selection: $model.draft.defaultTargetName) {
                    ForEach(model.targets) { target in
                        Text(target.name).tag(target.name)
                    }
                }
                hotkeyEditor
                Picker("Theme", selection: $model.draft.theme) {
                    Text("System").tag(Theme.system)
                    Text("Light").tag(Theme.light)
                    Text("Dark").tag(Theme.dark)
                }
            }

            Section("Anthropic API key (optional)") {
                Text("Only needed for the cloud engine. Leave blank to stay fully local.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if model.hasStoredKey {
                    HStack {
                        Text("A key is stored in the Keychain.")
                        Spacer()
                        Button("Remove", role: .destructive) { model.removeAPIKey() }
                    }
                }
                SecureField("sk-ant-...", text: $model.apiKeyInput)
                HStack {
                    Spacer()
                    Button("Save key") { model.saveAPIKey() }
                        .disabled(model.apiKeyInput.isEmpty)
                }
                if let status = model.keyStatus {
                    Text(status).font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .onChange(of: model.draft) { model.apply() }
    }

    private var hotkeyEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Global hotkey")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Toggle("⌃", isOn: model.modifierBinding(.control))
                Toggle("⌥", isOn: model.modifierBinding(.option))
                Toggle("⇧", isOn: model.modifierBinding(.shift))
                Toggle("⌘", isOn: model.modifierBinding(.command))
                Picker("Key", selection: $model.draft.hotkey.key) {
                    ForEach(keyChoices, id: \.self) { key in
                        Text(key == "space" ? "Space" : key.uppercased()).tag(key)
                    }
                }
                .labelsHidden()
                .frame(width: 90)
            }
            .toggleStyle(.button)
        }
    }
}
#endif
