# Prompt Translator (macOS): Design Spec

**Date:** 2026-07-18
**Status:** Approved design, ready for implementation planning
**Scope:** Personal v1, built so it could productise later without a rearchitecture of the core logic

## 1. Summary

A native macOS menu-bar app that turns a rough, conversational prompt into one optimised for a specific AI tool. The user summons a capture window with a global hotkey, dictates or types a rough prompt, picks a target tool (Claude, GPT, Cursor, and others), and the app rewrites the prompt into that tool's optimal style and places the result on the clipboard. The app never runs the target model. Its only job is reshaping the text so it lands well when the user pastes it into the real tool.

The rewrite is performed by a swappable engine: a cloud engine (Anthropic API, Haiku by default) or a local engine (Ollama), switchable in settings. Rewriting is steered by editable per-model style guides shipped as seeded starting points that the user owns and can refresh on demand.

## 2. Goals and non-goals

### Goals
- Sub-five-second warm loop: hotkey, capture, pick target, translate, paste.
- Local-first and privacy-respecting: the whole dictate-to-translate pipeline can run fully offline when the local engine and local dictation are selected.
- Editable, transparent per-model style guides that the user controls.
- On-demand refresh of style guides with a human-approved diff, so guidance keeps pace with changing models.
- A history of raw input versus optimised output, tagged with target tool and engine, as both a record and an informal evaluation layer.
- Simple, modern UI with system-following light and dark mode.

### Non-goals (v1)
- Running the target model or showing its response (this is a translator, not a chat client).
- Multi-user support, accounts, or cloud sync.
- Automatic (unattended) refresh of style guides on a schedule.
- History search, filtering, editing of past entries, or retention limits.
- Cloud speech-to-text.

## 3. Core flow

Three actions, in order:

1. **Capture.** A global hotkey summons a small input window from the menu bar. The user dictates (local whisper.cpp) or types a rough prompt.
2. **Translate.** The user picks a target from a dropdown and hits translate. The app loads that target's style guide, assembles a meta-prompt (guide plus raw prompt plus rewrite instructions), and sends it to the active rewrite engine.
3. **Deliver.** The optimised prompt appears in the window, auto-copied to the clipboard, with an explicit copy button and a before/after toggle. The user pastes it into the real tool.

## 4. Architecture

The whole design hinges on one decision: the rewrite engine sits behind a single interface so nothing else in the app knows or cares whether the brain is cloud or local. Units and their boundaries:

### 4.1 Rewrite Engine (swappable brain)
A protocol with one job: given a meta-prompt, return rewritten text. Two concrete implementations:
- **CloudEngine:** Anthropic API, Haiku by default. Reuses existing API wiring from the VoiceInk fork.
- **LocalEngine:** talks to the local Ollama endpoint (OpenAI-compatible), default model Qwen 2.5 7B, configurable.

The rest of the app holds a reference to "an engine" and calls `rewrite(...)`. Switching cloud and local means swapping the concrete type behind the protocol.

### 4.2 Style Guide Store
Owns the per-model guides. Loads them, saves edits, and hands the right one to the Translator on request. Knows nothing about rewriting or UI.

### 4.3 Translator (orchestrator)
Takes a raw prompt plus a target name, asks the Store for that target's guide, assembles the meta-prompt, hands it to the active Engine, returns the result. The single place the meta-prompt is built, and therefore the single place translation behaviour is tuned. After a successful translation it notifies the History Store.

### 4.4 Refresh Service
Separate from the translation path. On button press, for the chosen target(s): runs a research call (LLM plus web search, reusing CloudEngine) for current best practice, drafts a proposed new guide, and produces a diff against the stored guide. Hands the diff to the UI. Writes back through the Store only after the user approves.

### 4.5 Dictation Service
Turns speech into text via on-device whisper.cpp (reusing VoiceInk wiring) and feeds the capture window. Sits behind a clean edge so the UI just receives text and does not care whether it was typed or spoken.

### 4.6 History Store
Sibling to the Style Guide Store. Notified by the Translator after a successful translation; decides how to persist the entry. The History tab reads from it. Recording is isolated from translation logic.

### 4.7 UI (SwiftUI, menu bar)
Capture window, target dropdown, before/after view, history tab, settings pane (engine choice, model choice, API key, hotkey, default target), and the guide editor plus refresh/diff view. Talks to the Translator, Refresh Service, Dictation Service, and History Store. Never talks to an Engine directly.

**Shape in one line:** UI to Translator to (Style Guide Store plus Rewrite Engine); Dictation Service feeds capture; Refresh Service to Store, gated by UI approval; History Store notified after each translation.

The only genuinely Mac-locked unit is the UI. Everything below it is portable logic, which is what preserves the option to productise later.

## 5. Data model

File-based. No database, no cloud sync in v1.

### 5.1 Style guides
One editable Markdown file per target, in a known folder. Markdown is human-readable, diffs cleanly (needed for refresh), and an LLM reads and writes it easily. Each guide is structured prose (model preferences, how to structure instructions, formatting conventions, common pitfalls) with a small metadata header (target name, last-refreshed date). Shipped seeded; the user owns and edits them thereafter, in-app or in an external editor.

### 5.2 Settings
One small config file (JSON or plist): active engine, model per engine, global hotkey, default target, and theme handling (system-following by default).

### 5.3 Secrets
The Anthropic API key lives in the macOS Keychain, not in a file, keeping it out of anything that might be committed or synced.

### 5.4 History
An append-only JSON Lines file in the same known folder. One entry per translation, written the moment a translation completes:
- raw input, stored **verbatim** (unpolished, as dictated or typed)
- optimised output
- target tool
- engine used (local or cloud) and the specific model, e.g. "Local · Qwen 2.5 7B" or "Cloud · Haiku"
- timestamp

## 6. History tab

A second tab: reverse-chronological list. Each row shows target plus an engine badge plus timestamp, and expands to show the full raw-versus-optimised pair side by side. A copy button on the output makes old translations reusable. No editing of entries, no auto-deletion; a "clear history" button covers cleanup. Search and filter are deferred.

## 7. UI and design

Simple, modern, minimal chrome. System-following light and dark mode. The input field and the before/after view do the heavy lifting; nothing fussy around them. The capture window is small and keyboard-driven so the warm loop stays fast.

## 8. Local model guidance

Target hardware is an Apple Silicon M4 with 16 GB RAM, which runs 7B to 8B models comfortably and a 14B at Q4 if desired. Default local model is Qwen 2.5 7B (strong instruction following and structured rewriting), with the exact model exposed as a settings dropdown rather than hardcoded. Llama 3.3 8B is a reasonable alternative default. Model choice is config, not architecture.

## 9. Deferred items (clean later additions)

- History search and filter.
- Scheduled refresh with a review inbox (upgrade of the on-demand diff-and-approve flow).
- VoiceInk pipeline as a richer dictation plug-in beyond basic whisper.cpp capture.
- Multi-user, accounts, cloud sync (only if productising).
- Translation history editing and retention policies.
