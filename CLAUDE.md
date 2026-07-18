# CLAUDE.md: Prompt Translator (macOS)

Persistent context for this repo. Read this first every session.

## What this is

A native macOS menu-bar app that turns a rough, conversational prompt into one optimised for a specific AI tool (Claude, GPT, Cursor, and others). The user summons a capture window with a global hotkey, dictates or types a rough prompt, picks a target tool, and the app rewrites it into that tool's optimal style and puts the result on the clipboard.

The app does NOT run the target model. It only reshapes the text. The user pastes the result into the real tool themselves.

Personal v1 first, built so it could productise later without rearchitecting the core logic.

## Current status

Design approved. Full spec lives at:
`docs/superpowers/specs/2026-07-18-prompt-translator-macos-app-design.md`

Next step: implementation plan (writing-plans), then build.

## Tech stack

- **UI:** Swift / SwiftUI, menu-bar app. Modelled on the existing VoiceInk fork.
- **Build and run:** Xcode. Claude Code edits files; Xcode compiles, previews, signs, and handles entitlements (menu bar, global hotkey, Keychain).
- **Cloud engine:** Anthropic API, Haiku by default. Reuse the API wiring from the VoiceInk fork.
- **Local engine:** Ollama (OpenAI-compatible endpoint). Default model Qwen 2.5 7B, configurable in settings. Target hardware is an Apple Silicon M4 with 16 GB RAM.
- **Dictation:** on-device whisper.cpp in v1, reusing VoiceInk wiring.

## Architecture (units and boundaries)

The core decision: the rewrite engine sits behind ONE protocol so nothing else knows or cares whether the brain is cloud or local. Keep these boundaries clean.

- **Rewrite Engine**: protocol, one method: given a meta-prompt, return rewritten text. Two implementations: `CloudEngine` (Anthropic, Haiku) and `LocalEngine` (Ollama).
- **Style Guide Store**: owns per-model guides (editable Markdown files on disk). Loads, saves edits, hands the right guide to the Translator. Knows nothing about rewriting or UI.
- **Translator**: orchestrator. Takes raw prompt plus target, gets the guide, builds the meta-prompt, calls the active Engine, returns the result. The ONLY place the meta-prompt is assembled. Notifies the History Store on success.
- **Refresh Service**: on demand only. Researches current best practice per target (LLM plus web search, reusing CloudEngine), drafts a proposed guide, produces a diff. Writes back through the Store only after the user approves. No unattended scheduling in v1.
- **Dictation Service**: whisper.cpp speech to text, feeds the capture window. UI just receives text; it does not care if it was typed or spoken.
- **History Store**: sibling to the Style Guide Store. Notified by the Translator after each translation; persists the entry. The History tab reads from it.
- **UI (SwiftUI, menu bar)**: capture window, target dropdown, before/after view, history tab, settings, guide editor plus refresh/diff view. Talks to Translator, Refresh Service, Dictation Service, History Store. NEVER talks to an Engine directly.

The only Mac-locked unit is the UI. Everything below it is portable logic. Protect that property.

## Data model (file-based, no database, no cloud sync)

- **Style guides:** one editable Markdown file per target, in a known folder. Small metadata header (target name, last-refreshed date) plus structured prose. Shipped seeded; the user owns and edits them.
- **Settings:** one small JSON or plist file (active engine, model per engine, global hotkey, default target, theme).
- **Secrets:** Anthropic API key in the macOS Keychain, never in a file.
- **History:** append-only JSON Lines file in the same folder. One entry per translation: raw input stored VERBATIM (unpolished), optimised output, target tool, engine and specific model (e.g. "Local · Qwen 2.5 7B" or "Cloud · Haiku"), timestamp.

## Design

Simple, modern, minimal chrome. System-following light and dark mode. The input field and the before/after view do the heavy lifting. Capture window is small and keyboard-driven so the warm loop stays fast (target: hotkey, type, pick, translate, paste in under five seconds warm).

## Deferred (do NOT build in v1)

- Running the target model / showing its response.
- History search, filter, editing of entries, retention limits.
- Scheduled (unattended) style-guide refresh.
- Multi-user, accounts, cloud sync.
- Richer VoiceInk dictation plug-in beyond basic whisper.cpp capture.

## Conventions

- Keep each unit to one clear job behind a clean interface. If a file grows large, it is probably doing too much.
- Do not collapse the cloud/local engine boundary for convenience. It is the point.
- Do not use em dashes in generated docs or user-facing copy.
