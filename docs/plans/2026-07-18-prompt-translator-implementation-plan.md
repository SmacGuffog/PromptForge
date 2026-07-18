# Prompt Translator (macOS): Implementation Plan

**Date:** 2026-07-18
**Status:** Draft for review, no code written yet
**Companion spec:** `docs/superpowers/specs/2026-07-18-prompt-translator-macos-app-design.md`

## Purpose

A phased build order for PromptForge v1. Each phase leaves the project in a working, testable state and respects the one boundary the whole design rests on: nothing above the Rewrite Engine protocol knows or cares whether the brain is cloud or local.

Two working assumptions from the setup decisions:

1. **No VoiceInk fork.** The Anthropic client, the Ollama client, whisper.cpp dictation, and the menu-bar scaffolding are written fresh against the spec rather than lifted from an existing fork.
2. **Swift Package layout.** The portable core (`PromptForgeCore`) is a library target with no AppKit or SwiftUI. The Mac-locked UI (`PromptForgeApp`) is a separate executable target that depends on the core. This keeps the productisation option open by construction.

Because this is a macOS app, it is built and run on a Mac in Xcode (or `swift build` on a Mac). Nothing in this repository can be compiled or run in the Linux setup environment, so "done" for each phase means the code is written and, where noted, covered by unit tests that a Mac can run.

## Ground rules for every phase

- One unit, one job, behind a clean interface. If a file grows large it is probably doing too much.
- The UI never imports or references a concrete engine. It holds the Translator, Refresh Service, Dictation Service, and History Store, nothing lower.
- The meta-prompt is assembled in exactly one place: the Translator.
- Secrets live in the macOS Keychain, never in a file, never in git.
- No em dashes in generated docs or user-facing copy.
- Every core unit that can be tested without the UI gets tests as it lands.

## Phase 0: Scaffolding (this commit)

Already in place:

- `CLAUDE.md` and the design spec at their canonical paths.
- `README.md`, `.gitignore` (macOS, Xcode, SPM, secrets, model weights).
- `Package.swift` defining `PromptForgeCore`, `PromptForgeApp`, and `PromptForgeCoreTests`.
- Directory skeleton for the three targets.
- Seeded style guides for Claude, GPT, and Cursor under `Sources/PromptForgeCore/Resources/StyleGuides/`.
- This plan.

No Swift sources yet. The next commit (Phase 1) adds the first ones.

## Phase 1: Core types and the Rewrite Engine protocol

The seam the whole app hangs on, plus the value types that cross it.

- `Target`: the target tool identity (name, guide filename). Codable.
- `EngineKind`: `.cloud` or `.local`, with the specific model string for history labelling ("Cloud · Haiku", "Local · Qwen 2.5 7B").
- `RewriteEngine` protocol: one async method, given a fully assembled meta-prompt returns rewritten text, plus the `EngineKind` label it reports for history. Throws a typed error.
- `RewriteError`: network, auth, timeout, empty response, and engine-unavailable cases, so the UI can show something useful.
- A `FakeEngine` test double in the test target that returns a canned response, used to test everything above the seam without a network.

**Tests:** the protocol shape compiles and the fake behaves. Thin, but it locks the seam.

## Phase 2: Style Guide Store

Owns the per-target Markdown guides. Knows nothing about rewriting or UI.

- Resolve the on-disk guides folder in Application Support, seeding it from the bundled `Resources/StyleGuides` on first run so the user gets editable copies they own.
- Parse the small metadata header (target name, last-refreshed date) and hand back the guide body plus metadata.
- Load a guide by target, list available targets, save an edited guide back to disk.
- No knowledge of the Translator or any engine.

**Tests:** seeding on first run, load by target, round-trip save and reload, header parsing including a missing or malformed header.

## Phase 3: Settings and Keychain

The small config file and the one secret.

- `Settings` model: active engine, model per engine, global hotkey, default target, theme (system-following default). Codable to one JSON file in Application Support.
- Load with sensible defaults when the file is absent; save on change.
- Keychain wrapper for the Anthropic API key: read, write, delete. The key never touches the settings file or any other file.

**Tests:** settings defaults, round-trip encode and decode, missing-file path. Keychain access is exercised on a Mac since it needs the real Keychain.

## Phase 4: History Store

Sibling to the Style Guide Store. Append-only, isolated from translation logic.

- `HistoryEntry`: raw input stored verbatim, optimised output, target, engine label, timestamp. Codable.
- Append one entry as a line to a JSON Lines file in the known folder, written the moment a translation completes.
- Read all entries in reverse chronological order for the History tab.
- `clearHistory()` to support the History tab's clear button.

**Tests:** append then read back, verbatim preservation of raw input, ordering, clear.

## Phase 5: Translator (orchestrator)

The single place translation behaviour is tuned.

- Takes a raw prompt plus a target name. Asks the Store for that target's guide.
- Assembles the meta-prompt (guide plus raw prompt plus rewrite instructions) in this one place and nowhere else.
- Hands the meta-prompt to the active `RewriteEngine`, returns the result.
- On success, notifies the History Store with the raw input, the output, the target, and the engine label.
- Holds a reference to "an engine" via the protocol, never a concrete type.

**Tests:** with `FakeEngine`, verify the meta-prompt is assembled from the right guide, the result is returned unchanged, and a history entry is recorded once on success and not on failure.

## Phase 6: CloudEngine (Anthropic)

First concrete engine. Written fresh against the Anthropic Messages API using URLSession.

- Reads the API key from the Keychain wrapper.
- Haiku by default, model configurable from settings.
- Maps transport and API errors onto `RewriteError`.
- Reports its `EngineKind` label as "Cloud · <model>".

**Tests:** request construction and response parsing against recorded fixtures. Live calls are a manual check on a Mac with a real key.

## Phase 7: LocalEngine (Ollama)

Second concrete engine, same seam.

- Talks to the local Ollama OpenAI-compatible endpoint.
- Qwen 2.5 7B by default, model configurable from settings.
- Same `RewriteError` mapping, including a clear engine-unavailable case when Ollama is not running.
- Reports its `EngineKind` label as "Local · <model>".

**Tests:** request construction and response parsing against fixtures. Live calls are a manual check on a Mac running Ollama.

At the end of this phase the whole core is complete and switching cloud and local is swapping the concrete type behind the protocol, exactly as the spec requires.

## Phase 8: App shell and menu bar

First UI phase. `PromptForgeApp` becomes a real menu-bar app.

- Menu-bar entry point, no dock icon, app lifecycle.
- Global hotkey registration that summons the capture window, hotkey value from settings.
- Dependency wiring: build the active engine from settings, inject it into the Translator, wire the History Store, expose these to the views. This wiring is the only place that picks a concrete engine.

Built and run on a Mac. Entitlements for the global hotkey are handled in Xcode.

## Phase 9: Capture and translate flow

The warm loop the whole app is measured by.

- Small, keyboard-driven capture window: input field, target dropdown (defaulting to the settings default target), translate action.
- On translate: call the Translator, show progress, then show the optimised prompt.
- Auto-copy the result to the clipboard, an explicit copy button, and a before/after toggle.
- System-following light and dark mode.

Target: hotkey, type, pick, translate, paste in under five seconds warm.

## Phase 10: History tab

- Second tab, reverse-chronological list, reading from the History Store.
- Each row shows target plus an engine badge plus timestamp, expandable to the full raw-versus-optimised pair side by side.
- Copy button on the output. Clear-history button. No editing, no auto-deletion.

## Phase 11: Settings pane

- Engine choice, model per engine, API key entry (writes to Keychain), global hotkey, default target, theme.
- Changes persist through the Settings model and take effect on the next translation.

## Phase 12: Guide editor and Refresh Service

Last unit. Kept off the translation path.

- Guide editor: open a target's Markdown guide, edit, save back through the Style Guide Store.
- Refresh Service: on button press, for the chosen target, run a research call (LLM plus web search, reusing CloudEngine) for current best practice, draft a proposed guide, and produce a diff against the stored guide.
- Diff-and-approve view in the UI. Write back through the Store only after the user approves. No unattended scheduling in v1.

**Tests:** the diff production and the approve-then-write path, with the research call faked.

## Explicitly out of scope for v1

Carried straight from the spec so the plan does not creep:

- Running the target model or showing its response.
- History search, filter, editing of entries, retention limits.
- Scheduled (unattended) style-guide refresh.
- Multi-user, accounts, cloud sync.
- A richer VoiceInk dictation plug-in beyond basic whisper.cpp capture.

## Dictation note

The spec puts on-device whisper.cpp dictation into the capture window in v1. Since the VoiceInk wiring is not being reused, dictation is a self-contained slice that feeds text into the same capture field the keyboard uses, behind a `DictationService` edge so the UI does not care whether text was typed or spoken. It is sequenced after the capture flow (Phase 9) and can be built or deferred without touching any other unit, since nothing above it depends on how the text arrived. Confirm at that point whether it lands in the first v1 build or immediately after.

## Open questions to settle before or during the build

1. **Anthropic model id and API version.** Confirm the exact Haiku model id and Messages API version to pin in `CloudEngine`.
2. **Web search for Refresh.** The refresh research call needs a web-search capability. Confirm the mechanism (Anthropic server-side tool use, or a separate search path) before Phase 12.
3. **Guides folder location.** Application Support is assumed. Confirm the exact folder name and whether guides, settings, and history share one folder as the spec's "same known folder" implies.
4. **Bundle identifier and signing.** Set the bundle id and signing team in Xcode before the first run, since the global hotkey and Keychain need a signed app.
