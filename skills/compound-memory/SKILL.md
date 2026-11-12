---
name: compound-memory
description: Use when the user signals the session is wrapping up - checks whether anything worth remembering was never saved to Claude Code's Auto Memory.
---

# Compound Memory

**See also:** `superpowers:compound-learnings` — captures team-shared docs/solutions in `docs/solutions/` or `CONCEPTS.md`, not personal Auto Memory entries. Use this skill to catch missed captures at session wind-down; use `compound-learnings` for its own job.

## Overview

Claude Code's Auto Memory saves user/feedback/project/reference facts autonomously, mid-session, per its own "when to save" criteria. That coverage is incomplete: sessions end with things worth remembering that were never surfaced as save-worthy in the moment. This skill is a second pass, run at session wind-down, that catches what got missed — without requiring the user to remember to ask, and without adding friction to ordinary sessions.

## When this fires

<auto_invoke>
<trigger_phrases>
- "that's everything"
- "done for now"
- "wrapping up"
- "heading out"
- "that's it for today"
- "talk later"
- "all set"
- "ok we're good"
</trigger_phrases>
<manual_override>
Ask for compound-memory by name to check for anything to remember, without waiting for auto-detection.
</manual_override>
</auto_invoke>

Two hooks make this deterministic rather than relying on judgment: `trigger-nudge` (UserPromptSubmit) matches the phrases above, and `session-start` adds a nudge after compaction. After compaction, scan the compaction summary, including its "Unsaved memory candidates" section, and wait for a natural pause rather than interrupting the task in progress.

## Process

1. **Scan.** Review the session against the four memory types already defined in the Auto Memory system instructions — user, feedback, project, reference — using their existing "when to save" criteria. This skill does not define new criteria; it applies the existing ones as a second pass over the whole session.
2. **Dedup.** Cross-check candidates against the current `MEMORY.md` index (already loaded in context). Drop anything already captured there or in a linked topic file. If `MEMORY.md` doesn't exist yet (no memories saved so far), treat that the same as an empty index — there's nothing to dedup against, so all scan candidates are gaps. Only genuine gaps reach step 3.
3. **Check for stale entries.** Compare existing memories listed in `MEMORY.md` against the session. An entry is stale when the session contradicted or superseded it, or when it is a project status snapshot (a PR "merged", follow-ups "pending", a branch "in progress") whose state the session changed. Each stale entry becomes a candidate to update or delete.
4. **Report or stay silent.**
   - **No candidates survive dedup and no entry is stale:** say nothing beyond the normal conversational wrap-up. Do not mention this skill ran. This is the common case and must add zero friction.
   - **Candidates or stale entries exist:** present them as a single short bulleted list, one line each (add / update / delete, type, one-line summary), then ask once, in batch, which (if any) to apply. Do not ask per-item. Do not write anything before the user answers.
5. **Write.** For each change the user confirms, use the existing two-step Auto Memory write process unchanged: create/update/delete the topic file (frontmatter with `name`, `description`, `metadata.type`), then add, edit or remove the one-line index entry in `MEMORY.md`. No new file format, no new storage location.

## Example

> User: "Great, that's everything for today, thanks!"
>
> Claude: "Before we wrap up — two things from this session aren't in memory yet:
> - **(project)** This service's staging deploy requires a manual DB migration step not covered by CI
> - **(feedback)** You want PR descriptions kept under 3 bullet points
>
> Want me to save either of these?"

## Non-goals

- No `Stop` or `SessionEnd` hook, and no transcript scanning outside the live session.
- No raw-transcript retention.
- No changes to `compound-learnings` (team docs) — this skill only adds missed captures.
