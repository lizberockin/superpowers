# Trigger router: one hook enforces every skill's declared trigger phrases

## Goal

Turn the `<trigger_phrases>` convention into a contract that one `UserPromptSubmit` hook enforces for every skill that declares it, so adding a deterministic trigger to a skill means adding a block of text to that skill and nothing else.

## Problem

`hooks/wrap-up-nudge` is the fork's only deterministic skill trigger. It is hard-wired to one skill: it reads phrases from `skills/compound-memory/SKILL.md` only and its message says "invoke superpowers:compound-memory". The comment in the hook states the intended convention ("Trigger phrases are read from the skill itself so the two cannot drift"), but only one skill benefits.

A second skill already declares the same convention and gets nothing. `skills/compound-learnings/SKILL.md:714` holds `<auto_invoke> <trigger_phrases> - "that worked" - "it's fixed" - "working now" - "problem solved" </trigger_phrases>` on a single line. The hook's parser reads one phrase per line starting with `- "`, so it prints nothing for that block, and no other hook reads it: the skill's documented auto-invoke fires only by model judgment. The compound-memory design record puts that judgment-based invocation at roughly zero for that skill (it was effectively never invoked across 120 sessions before the hook existed).

Considered and rejected for this piece of work: a once-per-session marker (new state; a curated phrase list and "consider" wording are enough), nudges on `git commit` or `gh pr create` (rejected earlier: it fires rarely because commits happen only on request), capture on correction phrases (Auto Memory already saves corrections), and phrases for any other skill.

## Design

### Hook

- Rename `hooks/wrap-up-nudge` to `hooks/trigger-nudge` (it is no longer wrap-up-specific) and update `hooks/hooks.json`, `tests/hooks/test-memory-hooks.sh`, the sentence in `skills/compound-memory/SKILL.md` that names the hook, and the header comment.
- Behaviour that stays the same: reads the hook JSON from stdin (`prompt` via `jq`, falling back to the raw input without it), exits 0 with no output for empty prompts, for prompts longer than 120 characters, and when nothing matches; matches phrases case-insensitively on word boundaries; emits `hookSpecificOutput.additionalContext` JSON for `UserPromptSubmit`.
- New: instead of one hard-coded file, scan every `skills/*/SKILL.md` (relative to the hook's own location, in alphabetical order) that contains a `<trigger_phrases>` block. Each skill whose phrases match contributes one nudge, using its first matching phrase and its own wording; the nudges are joined into a single `additionalContext` in alphabetical skill order, so a prompt such as "it's fixed, done for now" nudges both `compound-learnings` (consider) and `compound-memory` (invoke now). Each nudge names the skill's directory name as `superpowers:<name>`.
- Phrase format is unchanged: one `- "phrase"` per line between `<trigger_phrases>` and `</trigger_phrases>`; the opening tag must start its line (a prose mention of the tag does not start a block), a block closed on the same line as it opens is ignored, and Windows line endings are tolerated.

### Per-skill wording

- An optional `mode="consider"` attribute on the skill's opening `<auto_invoke ...>` tag selects softer wording. Without it the nudge says to invoke the skill now (today's `compound-memory` behaviour, which is safe because that skill stays silent when there is nothing to save). With it the nudge says: the user's message matches a trigger for `superpowers:<name>`; consider invoking it if it applies.
- The wording lives in the skill file next to its phrases, so the hook stays generic. An unrecognised mode value is treated as the default.

### `compound-learnings`

- Reformat the block at `skills/compound-learnings/SKILL.md:714` to multi-line, one phrase per line, and add `mode="consider"` to its `<auto_invoke>` tag.
- Keep three phrases: "it's fixed", "working now", "problem solved". Drop "that worked" (common mid-debugging; the skill is about 9,800 words).
- Leave the `<manual_override>` text unchanged.

## Testing

Extend `tests/hooks/test-memory-hooks.sh`, written before the hook changes:

- A helper that builds a throwaway plugin root (`hooks/` containing a copy of the hook, `skills/` containing fixture skills) so the hook's own-location lookup finds fixtures, and runs the hook from there.
- Two fixture skills: one with a default `<auto_invoke>` block and one with `mode="consider"`. Assert: a default-mode phrase yields "invoke ... now" naming that skill; a consider-mode phrase yields the "consider" wording naming that skill; a prompt matching neither is silent; a prompt matching two skills gets both skills' nudges with each skill's own wording; a phrase in a skill later in alphabetical order still matches; an unrecognised mode value behaves as the default; a block with Windows line endings parses; a prose mention of the opening tag does not leak later bullets; a skill whose block has no parseable phrase lines is silently ignored and does not break the others; prompts over 120 characters are silent.
- A parse guard against the real `skills/`: every skill file containing `<trigger_phrases>` yields at least one phrase with the hook's extraction. This fails today for `compound-learnings`, and would catch any future one-line block.
- All existing cases in the file keep passing, including the compound-memory phrases and the `pre-compact` and `session-start` cases.
- `scripts/lint-shell.sh` passes on the renamed hook and the test.

## Known limits

- Only two skills declare phrases today; the mechanism is ahead of its users.
- Every matching skill is nudged, so a prompt matching several skills gets several nudges in one message; the order is alphabetical by directory name, not by priority.
- A prompt over 120 characters never nudges, so a wrap-up phrase inside a long message is missed. This is the existing trade-off against false positives.

## Non-goals

- No state, no once-per-session marker, no new hooks or events.
- No change to `pre-compact`, `session-start`, or the compound-memory scan logic.
- No phrases for skills other than `compound-memory` and `compound-learnings`, and no change to `skills/writing-skills/SKILL.md`.
