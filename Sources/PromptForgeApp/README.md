# PromptForgeApp

The macOS SwiftUI menu-bar UI. The only Mac-locked target. It imports SwiftUI, AppKit, and Carbon, talks to `PromptForgeCore`, and never talks to a rewrite engine directly. All source is guarded with `#if os(macOS)` so the package still builds on other platforms (with a stub entry point).

## Landed (Phase 8: app shell, hotkey, wiring)

- `PromptForgeApp.swift`: the `@main` menu-bar app (`MenuBarExtra`), with a non-macOS stub.
- `AppDelegate.swift`: accessory activation (no dock icon), owns the composition root, the global hotkey, and the capture panel (a floating `NSPanel`).
- `AppEnvironment.swift`: the composition root. The one place the concrete stores and active engine are built and wired into a `Translator`; `update(settings:)` rebuilds the engine when settings change.
- `HotkeyManager.swift`: a system-wide hotkey via Carbon `RegisterEventHotKey` (no Accessibility permission needed), firing a callback that summons the capture window.

## Landed (Phase 9: capture and translate flow)

- `CaptureViewModel.swift`: holds the input, target selection, and result; runs a translation and auto-copies the output to the clipboard.
- `CaptureView.swift`: the small, keyboard-driven capture window: input field, target dropdown, translate (Cmd+Return), a before/after toggle, and a copy button. Escape closes it.

## Landed (Phase 10: History tab)

- `HistoryView.swift`: a reverse-chronological list (`RootView` hosts it as a tab). Each row shows the target, an engine badge, and the timestamp, and expands to the raw-versus-optimised pair with a copy button. A clear-history button covers cleanup.
- `RootView.swift`: the tabbed window container (Capture, History, Settings), applying the theme.

## Landed (Phase 11: Settings pane)

- `SettingsView.swift`: engine and per-engine model, default target, global hotkey (modifier toggles plus a key picker), theme, and an optional Anthropic API key (stored in the Keychain, only needed for the cloud engine). Changes apply live through the composition root, which persists them and rebuilds the engine; `AppDelegate` re-registers the hotkey when it changes.

## Planned (later phases)

- The guide editor plus refresh diff view.
- whisper.cpp dictation feeding the capture field.

## Running it

This target is a menu-bar app. On a Mac you can launch it with `swift run PromptForgeApp` for a quick look, or wrap these sources in an Xcode app target for proper entitlements and signing (needed for distribution, menu-bar-only Info.plist, and the like).
