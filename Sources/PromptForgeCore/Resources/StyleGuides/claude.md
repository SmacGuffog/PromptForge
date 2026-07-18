---
target: Claude
last_refreshed: 2026-07-18
---

# Style guide: Claude

How to reshape a rough prompt so it lands well with Anthropic's Claude models. This is a seeded starting point. You own it and can edit or refresh it.

## Model preferences

- Claude follows explicit, structured instructions well and rewards clear role and task framing.
- It handles long, well-organised context comfortably. Give it the relevant material rather than making it guess.
- It responds well to being told the goal and the audience, not just the mechanical task.

## How to structure instructions

- Open with a one-line statement of the task and the desired outcome.
- Put stable, reusable context (background, source material, constraints) before the specific request.
- Use XML-style tags to fence distinct sections when a prompt has several parts, for example `<context>`, `<task>`, `<format>`. Claude keys on these boundaries reliably.
- State what to do rather than what to avoid where possible. Positive instructions are followed more consistently.
- If the output feeds another step, say so and name the exact shape you need back.

## Formatting conventions

- Ask for the specific output format explicitly (headings, bullet list, table, JSON) and give a short example when the shape matters.
- For structured data, describe the schema and ask for the data only, with no preamble.
- Prefer Markdown for prose answers unless another format is requested.

## Common pitfalls

- Vague asks produce hedged, over-general answers. Add the concrete goal and any constraints.
- Burying the actual request under long context makes it easy to miss. Lead with it or repeat it at the end.
- Asking for too many things in one prompt dilutes each. Split or prioritise.
- Do not tell it only what not to do. Pair every prohibition with the preferred behaviour.

## Rewrite intent

Turn a conversational, half-formed request into a clearly framed instruction: explicit task and outcome up front, relevant context fenced and ordered, the required output format named, and any constraints stated positively. Preserve the user's actual intent and any specifics they gave; do not invent requirements they did not state.
