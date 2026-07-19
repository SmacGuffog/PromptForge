#if os(macOS)
import SwiftUI

/// The menu-bar app entry point.
///
/// A status-bar item with a small menu; the real work happens in the capture
/// window, which the global hotkey or the "Open" menu item summons. The app has
/// no dock icon (accessory activation policy, set in `AppDelegate`).
@main
struct PromptForgeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra("PromptForge", systemImage: "wand.and.stars") {
            Button("Open PromptForge") { appDelegate.showCapture() }
                .keyboardShortcut("o")
            Divider()
            Button("Quit PromptForge") { NSApplication.shared.terminate(nil) }
                .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
#else
/// Non-macOS placeholder so the executable target still builds. PromptForge is a
/// macOS app; there is no UI on other platforms.
@main
struct PromptForgeApp {
    static func main() {
        print("PromptForge is a macOS app. Build and run it on macOS.")
    }
}
#endif
