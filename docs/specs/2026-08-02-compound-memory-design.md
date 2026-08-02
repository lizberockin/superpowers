# Compound Memory: session wind-down capture for Claude Code's Auto Memory

## Goal

Add a new superpowers skill, `compound-memory`, that catches memory-worthy facts a session surfaced but never got saved, by prompting for confirmation at natural session-ending moments — without requiring the user to remember to ask for it, and without nagging on ordinary sessions where nothing was missed.

## Problem

Claude Code's built-in Auto Memory already saves user/feedback/project/reference facts autonomously, mid-session, per the criteria in its own system instructions. In practice that coverage is incomplete: a session can end with things worth remembering that were never surfaced as save-worthy in the moment, and the user has no lightweight way to catch that gap before closing the session — their only recourse today is to explicitly ask Claude to save something, which requires remembering to ask.

This was scoped against two alternatives during design discussion:

- **Adopting Link** (github.com/gowtham0992/link), a standalone multi-agent memory store with MCP/CLI/hooks and review-gated writes. Rejected: its differentiators (cross-agent portability, deterministic non-LLM retrieval, benchmarked recall) target problems this user doesn't have (Claude Code only, single agent). Adopting it would mean maintaining a second markdown vault alongside the one Auto Memory already writes, for no net new capability once cross-agent support is off the table.
- **compound-engineering's pattern** (`ce-compound`'s "Phase 0.5: Auto Memory Scan") — this only *reads* MEMORY.md as supplementary evidence for its own docs/solutions writing; it has no session-end capture mechanism to borrow, and it targets team-shared repo knowledge, not personal cross-project memory.

Two trigger mechanisms were considered for firing the reminder:

- **A `Stop` hook**, firing after every turn, silent unless a turn surfaced something unsaved. Deterministic — fires regardless of what the user says — but runs on every turn and needs careful tuning to avoid nagging. No existing `Stop`/`SessionEnd` hook exists in superpowers or compound-engineering to copy from; superpowers' only hook today is `SessionStart` (`hooks/hooks.json` + `hooks/session-start`), which injects `additionalContext` at session start/resume/compact — a different event, though the dispatch mechanics (hooks.json entry → script → `hookSpecificOutput.additionalContext`) would translate.
- **A semantic auto-invoke skill**, modeled on `compound-learnings`' existing `<auto_invoke>` trigger-phrase block (itself ported from `ce-compound`), firing on natural wind-down language. Zero hook complexity, reuses a pattern already proven in this repo. Misses the case where the user closes the terminal mid-conversation with no wind-down language at all.

**Decision: semantic auto-invoke skill.** Lower implementation cost, reuses an existing proven pattern, and the missed case (silent tab-close, no goodbye) was judged acceptable given the added complexity of a per-turn hook. Not revisited unless the missed case turns out to matter in practice.

## Design

### Trigger

`compound-memory` auto-invokes on wind-down language, following `compound-learnings`' exact block shape:

```
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
```

Exact phrasing is refined at implementation time to match natural speech; the list above is a starting set, not final.

### Scan

When triggered, review the session against the four memory types already defined in the Auto Memory system instructions (user, feedback, project, reference) and their existing "when to save" criteria — this skill does not define new criteria, it applies the existing ones as a second pass. Cross-check candidates against the current `MEMORY.md` index (already loaded in context) to exclude anything already captured, so the skill only ever surfaces gaps, not duplicates of autonomous mid-session saves.

### Presentation and consent

- **No candidates found:** say nothing beyond normal conversation wrap-up. This is the common case and must add zero friction.
- **Candidates found:** present a single short bulleted list — one line per candidate, type + summary — and ask once, in batch, which (if any) to save. Do not ask per-item. Do not write anything before this confirmation; this is the one place this skill is stricter than default Auto Memory behavior, which sometimes saves autonomously without asking.

### Write

Use the existing two-step Auto Memory write process unchanged: create/update the topic file (frontmatter with `name`, `description`, `metadata.type`), then add the one-line index pointer to `MEMORY.md`. No new file format, no new storage location, no changes to the existing memory system's schema.

## Non-goals

- No `Stop` or `SessionEnd` hook (deferred; see Problem section).
- No raw-transcript retention (Link's `raw/` concept) — out of scope, this skill only surfaces distilled candidates.
- No changes to `compound-learnings` or `consolidate-memory` — this skill is a sibling to `compound-learnings` (personal memory vs. team docs) and complementary to `consolidate-memory` (which cleans up existing entries; this skill adds missed ones).
- No cross-agent/multi-tool support.

## Relationship to existing skills

- **`compound-learnings`**: same trigger-block pattern, different target — `compound-learnings` writes team-shared `docs/solutions/`; `compound-memory` writes personal Auto Memory. Naming deliberately echoes it as a sibling, per the existing precedent of aligning ported/adjacent skill names to superpowers' flat, unprefixed convention (see `2026-07-19-gstack-compound-skills-integration-design.md`).
- **`anthropic-skills:consolidate-memory`**: unaffected. That skill is a hygiene pass over what's already saved (merge duplicates, fix stale facts, prune the index); `compound-memory` is a capture pass for what's missing. Both can run in the same project without conflict.

## Open questions (deferred to planning)

- Exact final wind-down trigger-phrase list.
- Whether the scan step needs any tooling beyond reading the current context and `MEMORY.md`, or whether it's pure prompt instruction (current expectation: pure prompt instruction, no scripts, matching this skill's low-complexity scope).
