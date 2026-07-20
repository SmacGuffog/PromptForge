#if os(macOS)
import Combine
import SwiftUI
import PromptForgeCore

/// Backs the Settings pane: edits a draft `Settings` and applies changes through
/// the composition root (persist plus rebuild the local engine).
@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var draft: PromptForgeCore.Settings
    let targets: [Target]
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
        self.draft = environment.settings
        self.targets = environment.availableTargets()
    }

    /// Apply the current draft: persist it and rebuild the engine.
    func apply() {
        environment.update(settings: draft)
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

/// The settings pane. PromptForge runs fully on-device, so this covers the local
/// model, the capture defaults, the hotkey, and the theme. There is no cloud
/// engine or API key.
struct SettingsView: View {
    @StateObject private var model: SettingsViewModel

    private let keyChoices: [String] = ["space"] + "abcdefghijklmnopqrstuvwxyz".map { String($0) }

    init(environment: AppEnvironment) {
        _model = StateObject(wrappedValue: SettingsViewModel(environment: environment))
    }

    var body: some View {
        Form {
            Section("Local model") {
                TextField("Ollama model", text: $model.draft.localModel)
                Text("The model tag served by Ollama, for example qwen2.5:7b. Run it with `ollama pull <tag>`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
