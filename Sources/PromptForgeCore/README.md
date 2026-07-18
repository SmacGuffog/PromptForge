# PromptForgeCore

Portable logic. No AppKit, no SwiftUI. This target must stay reusable outside macOS so the app could productise later without rearchitecting.

## Landed (Phase 1: core types and the engine seam)

- `Target` (`Target.swift`): identity of a target tool, name plus its guide filename.
- `EngineKind` and `EngineLabel` (`EngineKind.swift`): cloud-or-local, plus the specific model for history labelling (for example "Cloud · Haiku").
- `RewriteEngine` protocol and `RewriteError` (`RewriteEngine.swift`): the single seam everything above it depends on, and the typed failures it can report.

The test double `FakeEngine` lives in the test target and lets everything above the seam be tested without a network.

## Landed (Phase 2: Style Guide Store)

- `StyleGuide` and `GuideMetadata` (`StyleGuide.swift`): the parsed guide (metadata header plus Markdown body), with a lenient front-matter parser and a canonical serialiser that round-trips.
- `StyleGuideProviding` and `StyleGuideStore` (`StyleGuideStore.swift`): resolve the on-disk guides folder, seed it from the bundled guides on first run without overwriting user edits, list targets, load a guide by target, and save edits back. Knows nothing about rewriting or the UI.

## Landed (Phase 3: Settings and Keychain)

- `Settings`, `Hotkey`, `Theme`, and `SettingsStore` (`Settings.swift`): the config model (active engine, model per engine, hotkey, default target, theme) with defaults, tolerant decoding, and file-based JSON persistence. Default cloud model is `claude-haiku-4-5`; default local model is `qwen2.5:7b`.
- `SecretStore`, `KeychainError`, and `KeychainSecretStore` (`Keychain.swift`): the Anthropic API key in the macOS Keychain, behind a protocol so callers can be faked. Guarded so the module still compiles where Security is unavailable.

## Planned (later phases)

- `Translator`: the single place the meta-prompt is assembled.
- `HistoryStore`: append-only record of every translation.
- `RefreshService`: on-demand research and diff-and-approve guide updates.
- `CloudEngine` (Anthropic) and `LocalEngine` (Ollama): the two concrete `RewriteEngine` implementations.

`Resources/StyleGuides/` holds the seeded, editable per-target guides shipped with the app.
