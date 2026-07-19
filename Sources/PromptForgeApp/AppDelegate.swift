#if os(macOS)
import AppKit
import SwiftUI
import PromptForgeCore

/// Owns the app lifecycle, the composition root, the global hotkey, and the
/// capture window (a floating panel). The menu-bar item is provided by the
/// SwiftUI `App`; everything with side effects lives here.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var environment: AppEnvironment?
    private var hotkeyManager: HotkeyManager?
    private var capturePanel: NSPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar app: no dock icon.
        NSApp.setActivationPolicy(.accessory)

        do {
            environment = try AppEnvironment()
        } catch {
            NSLog("PromptForge failed to start: \(error.localizedDescription)")
            NSApp.terminate(nil)
            return
        }

        let manager = HotkeyManager { [weak self] in
            DispatchQueue.main.async {
                self?.showCapture()
            }
        }
        if let hotkey = environment?.settings.hotkey {
            manager.register(hotkey)
        }
        hotkeyManager = manager
    }

    /// Summon the capture window: bring the app forward and show the panel.
    func showCapture() {
        guard let environment else { return }
        let panel = capturePanel ?? makeCapturePanel(environment: environment)
        capturePanel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func makeCapturePanel(environment: AppEnvironment) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 360),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.title = "PromptForge"
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.titlebarAppearsTransparent = true

        let root = CaptureView(environment: environment) { [weak panel] in
            panel?.orderOut(nil)
        }
        panel.contentView = NSHostingView(rootView: root)
        return panel
    }
}
#endif
