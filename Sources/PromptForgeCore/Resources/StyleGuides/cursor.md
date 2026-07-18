---
target: Cursor
last_refreshed: 2026-07-18
---

# Style guide: Cursor

How to reshape a rough prompt so it lands well in Cursor, the AI code editor. Cursor prompts are about acting on a real codebase, so the shape differs from a general chat prompt. This is a seeded starting point. You own it and can edit or refresh it.

## Model preferences

- Cursor works against your open files and project context. Prompts should assume the code is visible and reference it concretely.
- It does best with a precise, scoped instruction: which file, which function, what change, what to leave alone.
- It handles concrete engineering language well: types, function names, error messages, expected behaviour.

## How to structure instructions

- Lead with the concrete action: add, fix, refactor, or explain, and name the target (file, function, symbol) where known.
- State the desired end behaviour and any acceptance check ("tests should pass", "the endpoint returns 200").
- Call out constraints: do not change the public API, keep the existing style, avoid new dependencies.
- Paste the exact error text or failing case when fixing a bug, rather than describing it loosely.
- If scope should be narrow, say so explicitly so the edit does not sprawl.

## Formatting conventions

- Ask for a specific, minimal diff or edit rather than a full rewrite unless a rewrite is intended.
- When you want an explanation instead of an edit, say "explain, do not change code".
- Reference files and symbols by their real names so the model anchors to the right place.

## Common pitfalls

- Vague scope leads to sprawling edits across unrelated files. Name the target and the boundary.
- Describing an error instead of pasting it loses the detail that pinpoints the fix.
- Not stating the acceptance check leaves "done" undefined. Give the observable outcome.
- Forgetting to forbid collateral changes lets refactors creep. State what must stay untouched.

## Rewrite intent

Turn a conversational, half-formed request into a scoped engineering instruction: the concrete action and target named, the desired end behaviour and acceptance check stated, constraints and out-of-scope areas called out, and any error or failing case included verbatim. Preserve the user's actual intent and specifics; do not invent files, symbols, or requirements they did not mention.
