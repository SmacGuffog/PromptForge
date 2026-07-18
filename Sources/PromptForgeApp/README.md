# PromptForgeApp

The macOS SwiftUI menu-bar UI. The only Mac-locked target. It imports SwiftUI and AppKit, talks to `PromptForgeCore`, and never talks to a rewrite engine directly.

Populated in the UI phases of the implementation plan. Planned contents:

- Menu-bar app entry point and global hotkey handling.
- Capture window (input field, target dropdown, translate action).
- Before/after view with copy button.
- History tab.
- Settings pane (engine, model, API key, hotkey, default target, theme).
- Guide editor plus the refresh diff-and-approve view.
