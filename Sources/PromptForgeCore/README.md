# PromptForgeCore

Portable logic. No AppKit, no SwiftUI. This target must stay reusable outside macOS so the app could productise later without rearchitecting.

Populated in Phase 1 onward of the implementation plan. Planned contents:

- `RewriteEngine` protocol and its two implementations, `CloudEngine` (Anthropic) and `LocalEngine` (Ollama).
- `StyleGuideStore`: loads, saves, and hands out per-target Markdown guides.
- `Translator`: the single place the meta-prompt is assembled.
- `HistoryStore`: append-only record of every translation.
- `RefreshService`: on-demand research and diff-and-approve guide updates.
- `Settings` model and file-based persistence.

`Resources/StyleGuides/` holds the seeded, editable per-target guides shipped with the app.
