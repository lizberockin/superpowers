# Compound Memory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `compound-memory` skill to superpowers that, at natural session wind-down moments, checks whether anything the session surfaced should be saved to Claude Code's Auto Memory but wasn't, and asks (once, in batch) before writing.

**Architecture:** A single-file, prompt-only skill (`skills/compound-memory/SKILL.md`) — no scripts, no hooks. It auto-invokes on wind-down trigger phrases, scans the session against Auto Memory's existing four save-criteria types, dedups against the current `MEMORY.md` index, and either stays silent or asks a single batch question before writing via the existing two-step Auto Memory process.

**Tech Stack:** Markdown skill file, following superpowers' `writing-skills` TDD-for-docs discipline (pressure-scenario subagents standing in for unit tests, since there's no executable code here).

## Global Constraints

- Skill name: `compound-memory` (fixed, per approved spec).
- No `Stop` or `SessionEnd` hook — semantic auto-invoke only.
- No new storage format, location, or schema — must reuse the existing Auto Memory two-step write process (topic file with `name`/`description`/`metadata.type` frontmatter, then one-line index entry in `MEMORY.md`) unchanged.
- Must never write before the user confirms — batch question only, never per-item.
- Must stay silent (no mention the skill ran) when no candidates survive dedup against the current `MEMORY.md` index.
- Source of truth for exact spec decisions: `docs/specs/2026-08-02-compound-memory-design.md`.

---

## File Structure

- Create: `skills/compound-memory/SKILL.md` — the entire deliverable. One file, one responsibility: this skill does nothing else and touches no other files.

This repo's `writing-skills` discipline treats skill-writing as TDD applied to documentation: a "test" is a pressure-scenario dispatched to a fresh subagent, "RED" is the subagent's behavior without the skill, "GREEN" is its behavior with the skill's content available. Because a same-session `Skill` tool invocation would run the cached pre-edit version of a skill you just wrote (Claude Code loads plugin/skill content at session start), every verification task below injects the skill's markdown directly into the dispatched subagent's prompt rather than relying on skill auto-discovery — this is the same workaround this codebase already documents for testing skill changes within one session.

---

### Task 1: Baseline pressure test (RED) — confirm the gap exists without the skill

**Files:**
- None created or modified. This task only produces observational evidence used to validate Task 2's content.

**Interfaces:**
- Produces: a recorded transcript excerpt (paste the subagent's final response into the task's completion notes) showing baseline behavior, used as the "before" comparison for Task 3.

- [ ] **Step 1: Dispatch the baseline subagent**

Use the Agent tool (general-purpose, foreground) with this exact prompt:

```
You are Claude Code, near the end of a coding session. Here is the relevant context:

- The project's Auto Memory index file (MEMORY.md) is currently empty — no memories saved yet this project.
- Earlier in this session, the user said: "oh by the way, this repo's staging deploy needs a manual DB migration step first — CI doesn't run it automatically, people keep forgetting and breaking staging."
- Later, the user said: "also, quick preference — keep PR descriptions to 3 bullet points max, I don't want to read essays."
- Neither of those was saved to memory during the session.

The user just sent this final message: "ok that's everything, thanks!"

Respond exactly as you normally would to end the session. Do not explain your reasoning or break character — just give the response you'd actually send.
```

- [ ] **Step 2: Record the result**

Expected (RED): the subagent's response is a plain sign-off (e.g. "You're welcome! Have a good one.") with no mention of saving the deploy-migration note or the PR-description preference to memory. This confirms the gap the skill needs to close — a real, save-worthy project fact and a real feedback-type fact were both surfaced in-session and neither got flagged for saving.

If the baseline subagent *does* spontaneously offer to save one or both — note which, and note it in Task 3's expected result too (Task 2's skill must still produce the correct behavior; this changes what counts as a meaningful diff, not what Task 2 builds).

- [ ] **Step 3: Commit nothing yet**

This task is observational only — there is no code or doc change to commit. Proceed to Task 2.

---

### Task 2: Write `skills/compound-memory/SKILL.md` (GREEN)

**Files:**
- Create: `skills/compound-memory/SKILL.md`

**Interfaces:**
- Produces: the skill's frontmatter `name: compound-memory` (referenced by name in Tasks 3-4's manual-invocation checks) and its four-step process (Scan → Dedup → Report or stay silent → Write), referenced by name in Tasks 3-4's pass/fail criteria.

- [ ] **Step 1: Create the skill file with this exact content**

```markdown
---
name: compound-memory
description: Use at natural session wind-down moments (the user signals they're done, wrapping up, or heading out) to check whether anything from the session should be saved to Claude Code's Auto Memory before it's lost.
---

# Compound Memory

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

## Process

1. **Scan.** Review the session against the four memory types already defined in the Auto Memory system instructions — user, feedback, project, reference — using their existing "when to save" criteria. This skill does not define new criteria; it applies the existing ones as a second pass over the whole session.
2. **Dedup.** Cross-check candidates against the current `MEMORY.md` index (already loaded in context). Drop anything already captured there or in a linked topic file. Only genuine gaps reach step 3.
3. **Report or stay silent.**
   - **No candidates survive dedup:** say nothing beyond the normal conversational wrap-up. Do not mention this skill ran. This is the common case and must add zero friction.
   - **Candidates survive:** present them as a single short bulleted list, one line per candidate (type + one-line summary), then ask once, in batch, which (if any) to save. Do not ask per-item. Do not write anything before the user answers.
4. **Write.** For each candidate the user confirms, use the existing two-step Auto Memory write process unchanged: create/update the topic file (frontmatter with `name`, `description`, `metadata.type`), then add the one-line index entry to `MEMORY.md`. No new file format, no new storage location.

## Example

> User: "Great, that's everything for today, thanks!"
>
> Claude: "Before we wrap up — two things from this session aren't in memory yet:
> - **(project)** This service's staging deploy requires a manual DB migration step not covered by CI
> - **(feedback)** You want PR descriptions kept under 3 bullet points
>
> Want me to save either of these?"

## Non-goals

- No `Stop` or `SessionEnd` hook — this is a semantic auto-invoke skill only.
- No raw-transcript retention.
- No changes to `compound-learnings` (team docs) or `consolidate-memory` (hygiene pass on existing entries) — this skill only adds missed captures.
```

- [ ] **Step 2: Verify frontmatter is well-formed**

Run: `head -5 skills/compound-memory/SKILL.md`
Expected:
```
---
name: compound-memory
description: Use at natural session wind-down moments (the user signals they're done, wrapping up, or heading out) to check whether anything from the session should be saved to Claude Code's Auto Memory before it's lost.
---
```

- [ ] **Step 3: Commit**

```bash
git add skills/compound-memory/SKILL.md
git commit -m "feat: add compound-memory skill for session wind-down memory capture"
```

---

### Task 3: Verify the candidates-found path (GREEN pressure test)

**Files:**
- None created or modified.

**Interfaces:**
- Consumes: `skills/compound-memory/SKILL.md` content from Task 2 (injected into the subagent prompt below).

- [ ] **Step 1: Dispatch the pressure-test subagent with the skill's content injected**

Use the Agent tool (general-purpose, foreground) with this exact prompt (the `<<<SKILL CONTENT>>>` block is the full literal contents of `skills/compound-memory/SKILL.md` from Task 2 — paste it in verbatim, do not summarize it):

```
You have access to the following skill. Follow it exactly as written when it applies to the situation below.

<<<SKILL CONTENT>>>
[paste full contents of skills/compound-memory/SKILL.md here]
<<<END SKILL CONTENT>>>

You are Claude Code, near the end of a coding session. Here is the relevant context:

- The project's Auto Memory index file (MEMORY.md) is currently empty — no memories saved yet this project.
- Earlier in this session, the user said: "oh by the way, this repo's staging deploy needs a manual DB migration step first — CI doesn't run it automatically, people keep forgetting and breaking staging."
- Later, the user said: "also, quick preference — keep PR descriptions to 3 bullet points max, I don't want to read essays."
- Neither of those was saved to memory during the session.

The user just sent this final message: "ok that's everything, thanks!"

Respond exactly as you normally would to end the session, applying the skill above.
```

- [ ] **Step 2: Check the result against pass criteria**

Expected (PASS):
- The response surfaces both candidates in a single bulleted list, each tagged with its type (`project` and `feedback`), before or alongside the sign-off.
- The response asks once, in batch, whether to save them (e.g. "want me to save either of these?") — not two separate questions, not one question per item.
- The response does not claim anything was already written to `MEMORY.md` — nothing should be saved until the (simulated) user answers.

FAIL conditions to watch for: per-item questions instead of one batch question; writing before confirmation; only surfacing one of the two candidates; generic "let me know if you want me to remember anything" phrasing that doesn't name the actual candidates (the skill requires concrete one-line summaries, not a generic offer).

If any FAIL condition is observed, revise the "Report or stay silent" and "Write" sections of `skills/compound-memory/SKILL.md` (Task 2) to close the gap, then re-run this step. Do not proceed to Task 4 until this passes.

- [ ] **Step 3: Commit nothing yet**

This task only validates Task 2's content. If Step 2 required a revision, amend and re-commit Task 2's commit (`git commit --amend`) or add a follow-up commit — either is fine since Task 4 hasn't run yet. Proceed to Task 4.

---

### Task 4: Verify the silent path and the dedup path (GREEN pressure tests, loophole check)

**Files:**
- None created or modified.

**Interfaces:**
- Consumes: `skills/compound-memory/SKILL.md` content from Task 2 (injected into both subagent prompts below), amended if Task 3 required changes.

- [ ] **Step 1: Dispatch the "nothing to save" pressure test**

Use the Agent tool (general-purpose, foreground) with this exact prompt (again with the full literal skill content injected):

```
You have access to the following skill. Follow it exactly as written when it applies to the situation below.

<<<SKILL CONTENT>>>
[paste full contents of skills/compound-memory/SKILL.md here]
<<<END SKILL CONTENT>>>

You are Claude Code, near the end of a coding session. Here is the relevant context:

- The project's Auto Memory index file (MEMORY.md) is currently empty.
- This session was purely mechanical: the user asked you to rename a variable across 4 files, you did it, tests passed. No preferences, decisions, or durable facts came up.

The user just sent this final message: "great, that's everything, thanks!"

Respond exactly as you normally would to end the session, applying the skill above.
```

Expected (PASS): a plain sign-off, no mention of memory, no candidates list, no statement like "nothing to save this time" (the skill requires silence, not an explicit "no-op" announcement). FAIL if the response mentions checking memory at all, or announces it found nothing.

- [ ] **Step 2: Dispatch the "already saved, don't re-suggest" pressure test**

Use the Agent tool (general-purpose, foreground) with this exact prompt:

```
You have access to the following skill. Follow it exactly as written when it applies to the situation below.

<<<SKILL CONTENT>>>
[paste full contents of skills/compound-memory/SKILL.md here]
<<<END SKILL CONTENT>>>

You are Claude Code, near the end of a coding session. Here is the relevant context:

- The project's Auto Memory index file (MEMORY.md) currently contains:
  - [Staging deploy migration step](project_staging_deploy.md) — staging deploys need a manual DB migration CI doesn't run
- Earlier in this session, the user repeated that same fact almost verbatim: "yeah don't forget staging needs that manual migration step before deploy, CI still doesn't cover it."
- No other new facts came up this session.

The user just sent this final message: "ok, wrapping up for today."

Respond exactly as you normally would to end the session, applying the skill above.
```

Expected (PASS): the response does not re-propose saving the staging-migration fact, since it's already in the index — this is the dedup step working. A plain sign-off, same as the silent-path case. FAIL if the response suggests saving a duplicate or near-duplicate entry for the same fact.

- [ ] **Step 3: Fix any loopholes found**

If either sub-step failed, revise the "Dedup" or "Report or stay silent" sections of `skills/compound-memory/SKILL.md` to close the gap (e.g. tighten the dedup instruction if it re-suggested a near-duplicate phrasing of an existing entry), then re-run the failing pressure test until it passes.

- [ ] **Step 4: Commit any revisions**

```bash
git add skills/compound-memory/SKILL.md
git commit -m "fix: close loophole in compound-memory dedup/silence behavior"
```

Skip this step if Steps 1-2 passed with no changes needed.

---

## Self-Review Notes

- **Spec coverage:** Trigger (Task 2 step 1's `<auto_invoke>` block), scan (Process step 1), dedup (Process step 2, verified in Task 4), presentation/consent (Process step 3, verified in Task 3), write (Process step 4, reuses existing Auto Memory mechanics verbatim, no new task needed since it's explicitly "no changes to the existing schema"). All spec sections have a corresponding task.
- **No placeholders:** every pressure-test prompt is written out in full; the skill file content in Task 2 is the complete, final text, not a description of what it should contain.
- **Naming consistency:** `compound-memory` is used identically in the frontmatter, the plan title, and every pressure-test prompt.

## Execution Handoff

Plan complete and saved to `docs/plans/2026-08-02-compound-memory-plan.md`. Two execution options:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
