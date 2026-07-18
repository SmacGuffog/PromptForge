# PromptForge

A native macOS menu-bar app that turns a rough, conversational prompt into one optimised for a specific AI tool (Claude, GPT, Cursor, and others). Summon a small capture window with a global hotkey, dictate or type a rough prompt, pick a target tool, and PromptForge rewrites it into that tool's optimal style and puts the result on the clipboard.

PromptForge does not run the target model. It only reshapes the text. You paste the result into the real tool yourself.

Personal v1, built so it could productise later without rearchitecting the core logic.

## Status

Design approved. Repository scaffolding and the implementation plan are in place. Implementation has not started yet.

- Design spec: [`docs/superpowers/specs/2026-07-18-prompt-translator-macos-app-design.md`](docs/superpowers/specs/2026-07-18-prompt-translator-macos-app-design.md)
- Implementation plan: [`docs/plans/2026-07-18-prompt-translator-implementation-plan.md`](docs/plans/2026-07-18-prompt-translator-implementation-plan.md)
- Persistent context for contributors and agents: [`CLAUDE.md`](CLAUDE.md)

## How it works

Three actions in order: capture, translate, deliver.

1. **Capture.** A global hotkey summons a small input window. You dictate (on-device whisper.cpp) or type a rough prompt.
2. **Translate.** You pick a target and hit translate. The app loads that target's style guide, assembles a meta-prompt (guide plus raw prompt plus rewrite instructions), and sends it to the active rewrite engine.
3. **Deliver.** The optimised prompt appears, auto-copied to the clipboard, with a before/after toggle. You paste it into the real tool.

## Architecture

The design hinges on one decision: the rewrite engine sits behind a single protocol, so nothing else in the app knows or cares whether the brain is cloud or local.

- **Rewrite Engine** (protocol): `CloudEngine` (Anthropic API, Haiku by default) and `LocalEngine` (Ollama, Qwen 2.5 7B by default).
- **Style Guide Store**: owns per-target Markdown guides on disk.
- **Translator**: the single place the meta-prompt is assembled.
- **Refresh Service**: on-demand research and diff-and-approve updates to guides.
- **Dictation Service**: on-device whisper.cpp speech to text.
- **History Store**: append-only record of every translation.
- **UI** (SwiftUI, menu bar): the only Mac-locked unit. Everything below it is portable logic.

## Project layout

This is a Swift Package. The portable core is separated from the Mac-locked UI so the core stays reusable.

```
Sources/
  PromptForgeCore/                   Portable logic (engines, store, translator, history). No AppKit or SwiftUI.
    Resources/StyleGuides/           Seeded, editable per-target Markdown style guides (bundled with the core).
  PromptForgeApp/                    macOS SwiftUI menu-bar UI. The only Mac-locked target.
Tests/
  PromptForgeCoreTests/              Unit tests for the portable core.
```

## Building

PromptForge is a macOS app and must be built on a Mac.

- Open `Package.swift` in Xcode, or run `swift build` from the repository root.
- Xcode handles compiling, previews, signing, and entitlements (menu bar, global hotkey, Keychain).

The current commit is scaffolding plus the plan. Source targets are created in Phase 1 of the implementation plan.

## Conventions

- Keep each unit to one clear job behind a clean interface.
- Do not collapse the cloud/local engine boundary for convenience. It is the point.
- Do not use em dashes in generated docs or user-facing copy.
- Secrets (the Anthropic API key) live in the macOS Keychain, never in a file.
