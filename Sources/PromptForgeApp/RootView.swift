#if os(macOS)
import SwiftUI
import PromptForgeCore

/// The window content: a tabbed container for capture, history, and settings.
/// Capture is the default tab so a summon lands on the fast path.
struct RootView: View {
    @ObservedObject var environment: AppEnvironment
    let onClose: () -> Void

    private enum Tab: Hashable {
        case capture, history, settings
    }

    @State private var tab: Tab = .capture

    var body: some View {
        TabView(selection: $tab) {
            CaptureView(environment: environment, onClose: onClose)
                .tabItem { Label("Capture", systemImage: "wand.and.stars") }
                .tag(Tab.capture)

            HistoryView(environment: environment)
                .tabItem { Label("History", systemImage: "clock") }
                .tag(Tab.history)

            SettingsView(environment: environment)
                .tabItem { Label("Settings", systemImage: "gearshape") }
                .tag(Tab.settings)
        }
        .frame(width: 520, height: 500)
        .preferredColorScheme(Self.colorScheme(for: environment.settings.theme))
    }

    private static func colorScheme(for theme: Theme) -> ColorScheme? {
        switch theme {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}
#endif
