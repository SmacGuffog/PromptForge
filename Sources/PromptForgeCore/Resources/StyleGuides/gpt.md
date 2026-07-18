---
target: GPT
last_refreshed: 2026-07-18
---

# Style guide: GPT

How to reshape a rough prompt so it lands well with OpenAI's GPT models. This is a seeded starting point. You own it and can edit or refresh it.

## Model preferences

- GPT responds strongly to an explicit role or persona ("You are a ...") that sets tone and expertise.
- It benefits from a clear, ordered breakdown of what to do, especially for multi-step tasks.
- It is concise by default when asked to be, and verbose when not. Say which you want.

## How to structure instructions

- Start with a role line when it helps set expertise or voice.
- Follow with the task stated as a direct instruction.
- For anything multi-step, lay the steps out as a numbered list so the order is unambiguous.
- Separate instructions from any input text with a clear delimiter (a line of context, triple quotes, or a labelled section) so the model does not confuse the two.
- State the constraints (length, tone, reading level, what to include or exclude) explicitly.

## Formatting conventions

- Name the output format directly and, for structured output, give a short template to fill in.
- For JSON or code, ask for that content only, with no surrounding commentary.
- Use headings and bullets for readable prose answers.

## Common pitfalls

- Leaving tone unset yields a generic, middle-of-the-road voice. Set the role and the tone.
- Mixing the instruction and the input without a delimiter causes the model to treat input as commands. Fence them apart.
- Open-ended length produces bloat. Give a target length or a hard cap.
- Compound requests get uneven attention. Order them and mark the priority.

## Rewrite intent

Turn a conversational, half-formed request into a directed instruction: an optional role line, the task stated plainly, multi-step work laid out as ordered steps, input clearly delimited from instructions, and explicit constraints on format, length, and tone. Preserve the user's actual intent and specifics; do not add requirements they did not state.
