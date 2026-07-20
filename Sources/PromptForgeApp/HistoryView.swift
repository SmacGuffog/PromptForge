#if os(macOS)
import AppKit
import Combine
import SwiftUI
import PromptForgeCore

/// Reads history for the History tab.
@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var entries: [HistoryEntry] = []
    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func reload() {
        entries = (try? environment.history.entries()) ?? []
    }

    func clear() {
        try? environment.history.clear()
        reload()
    }

    func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}

/// A reverse-chronological list of past translations. Each row shows the target,
/// an engine badge, and the timestamp, and expands to the raw-versus-optimised
/// pair with a copy button on the output.
struct HistoryView: View {
    @StateObject private var model: HistoryViewModel

    init(environment: AppEnvironment) {
        _model = StateObject(wrappedValue: HistoryViewModel(environment: environment))
    }

    var body: some View {
        VStack(spacing: 0) {
            if model.entries.isEmpty {
                emptyState
            } else {
                list
            }
            Divider()
            HStack {
                Spacer()
                Button("Clear history", role: .destructive) { model.clear() }
                    .disabled(model.entries.isEmpty)
            }
            .padding(8)
        }
        .onAppear { model.reload() }
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Spacer()
            Image(systemName: "clock")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("No translations yet")
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        List(model.entries) { entry in
            DisclosureGroup {
                VStack(alignment: .leading, spacing: 8) {
                    labelled("Before", text: entry.rawInput)
                    labelled("Optimised", text: entry.optimisedOutput)
                    HStack {
                        Spacer()
                        Button("Copy") { model.copy(entry.optimisedOutput) }
                    }
                }
                .padding(.vertical, 4)
            } label: {
                HStack {
                    Text(entry.target).fontWeight(.medium)
                    Text(entry.engine.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.15), in: Capsule())
                    Spacer()
                    Text(entry.timestamp.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func labelled(_ title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
        }
    }
}
#endif
