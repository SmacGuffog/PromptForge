# PromptForgeCore

Portable logic. No AppKit, no SwiftUI. This target must stay reusable outside macOS so the app could productise later without rearchitecting.

## Landed (Phase 1: core types and the engine seam)

- `Target` (`Target.swift`): identity of a target tool, name plus its guide filename.
- `EngineKind` and `EngineLabel` (`EngineKind.swift`): cloud-or-local, plus the specific model for history labelling (for example "Cloud · Haiku").
- `RewriteEngine` protocol and `RewriteError` (`RewriteEngine.swift`): the single seam everything above it depends on, and the typed failures it can report.

The test double `FakeEngine` lives in the test target and lets everything above the seam be tested without a network.

## Planned (later phases)

- `StyleGuideStore`: loads, saves, and hands out per-target Markdown guides.
- `Translator`: the single place the meta-prompt is assembled.
- `HistoryStore`: append-only record of every translation.
- `RefreshService`: on-demand research and diff-and-approve guide updates.
- `Settings` model and file-based persistence.
- `CloudEngine` (Anthropic) and `LocalEngine` (Ollama): the two concrete `RewriteEngine` implementations.

`Resources/StyleGuides/` holds the seeded, editable per-target guides shipped with the app.
