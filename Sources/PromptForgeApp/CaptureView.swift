#if os(macOS)
import SwiftUI
import PromptForgeCore

/// The small, keyboard-driven capture window: type a rough prompt, pick a
/// target, translate, and see the optimised result (auto-copied to the
/// clipboard) with a before/after toggle.
struct CaptureView: View {
    @StateObject private var model: CaptureViewModel
    private let onClose: () -> Void

    init(environment: AppEnvironment, onClose: @escaping () -> Void) {
        _model = StateObject(wrappedValue: CaptureViewModel(environment: environment))
        self.onClose = onClose
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            inputSection
            controls
            if let error = model.errorMessage {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
            }
            if model.output != nil {
                Divider()
                resultSection
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onExitCommand(perform: onClose)
    }

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Rough prompt")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $model.inputText)
                .font(.body)
                .frame(minHeight: 90)
                .padding(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.secondary.opacity(0.3))
                )
        }
    }

    private var controls: some View {
        HStack {
            Picker("Target", selection: $model.selectedTarget) {
                ForEach(model.targets) { target in
                    Text(target.name).tag(Optional(target))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 180)

            Spacer()

            Button(action: model.translate) {
                if model.isTranslating {
                    ProgressView().controlSize(.small)
                } else {
                    Text("Translate")
                }
            }
            .keyboardShortcut(.return, modifiers: .command)
            .disabled(!model.canTranslate)
        }
    }

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(model.showingBefore ? "Before" : "Optimised")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button(model.showingBefore ? "Show optimised" : "Show before") {
                    model.showingBefore.toggle()
                }
                .buttonStyle(.link)
                if let output = model.output {
                    Button("Copy") { model.copyToClipboard(output) }
                }
            }
            ScrollView {
                Text(model.showingBefore ? model.inputText : (model.output ?? ""))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }
            .frame(minHeight: 90)
        }
    }
}
#endif
