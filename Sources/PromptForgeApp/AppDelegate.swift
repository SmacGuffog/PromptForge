#if os(macOS)
import AppKit
import Combine
import SwiftUI
import PromptForgeCore

/// Owns the app lifecycle, the composition root, the global hotkey, and the
/// window (a floating panel with capture, history, and settings tabs). The
/// menu-bar item is provided by the SwiftUI `App`; everything with side effects
/// lives here.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var hotkeyManager: HotkeyManager?
    private var window: NSPanel?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar app: no dock icon.
        NSApp.setActivationPolicy(.accessory)

        let env: AppEnvironment
        do {
            env = try AppEnvironment()
        } catch {
            NSLog("PromptForge failed to start: \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }
        environment = env

        let manager = HotkeyManager { [weak self] in
            DispatchQueue.main.async {
                self?.showWindow()
            }
        }
        hotkeyManager = manager

        // Register the hotkey now and again whenever the setting changes.
        env.$settings
            .map(\.hotkey)
            .removeDuplicates()
            .sink { hotkey in manager.register(hotkey) }
            .store(in: &cancellables)
    }

    /// Summon the window: bring the app forward and show the panel.
    func showCapture() {
        showWindow()
    }

    private func showWindow() {
        guard let environment else { return }
        let panel = window ?? makeWindow(environment: environment)
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(environment: AppEnvironment) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "PromptForge"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true

        let root = RootView(environment: environment) { [weak panel] in
            panel?.orderOut(nil)
        }
        panel.contentView = NSHostingView(rootView: root)
        return panel
    }
}
#endif
