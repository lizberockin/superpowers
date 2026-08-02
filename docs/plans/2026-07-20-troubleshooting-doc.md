# Troubleshooting Doc Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create `TROUBLESHOOTING.md` as a hand-curated, linked index over the 13 skill files that already carry Red Flags / Common Mistakes / Anti-Pattern content, plus four cross-cutting failure-mode entries quoting already-documented content. Link to it from `README.md` and `skills/using-superpowers/SKILL.md`.

**Architecture:** A single new markdown file at repo root, containing links (not copies) to existing sections in `skills/*/SKILL.md`. No script, no generator, no test suite — this is a hand-maintained index, per the design spec's non-goals (the source content is too heterogeneous for reliable mechanical extraction).

**Tech Stack:** Markdown only.

## Global Constraints

- Every link in `TROUBLESHOOTING.md` must resolve to a real heading anchor — verify each one by grepping the target file's actual heading text and computing its GitHub slug, not by assuming the draft in the design spec is already correct (two anchors in the spec's draft were wrong: the SDO section needed `-sdo` appended, and there is no `#task-dispatch` heading — it's `#constructing-reviewer-prompts`).
- No content is copied from a skill file into `TROUBLESHOOTING.md` beyond a one-sentence summary for the four cross-cutting entries — the full text stays in the skill file, linked. (Spec: "Non-goals")
- The `README.md` and `using-superpowers/SKILL.md` edits are single-line additions; nothing else in either file changes. (Spec: "Design, sections 2-3")

---

### Task 1: Write TROUBLESHOOTING.md, verify every anchor, link from README and using-superpowers

**Files:**
- Create: `TROUBLESHOOTING.md`
- Modify: `README.md` (one line)
- Modify: `skills/using-superpowers/SKILL.md` (one line)

**Interfaces:**
- Consumes: existing heading text in 13 `skills/*/SKILL.md` files (read-only) plus the four already-verified source quotes from the design spec.
- Produces: `TROUBLESHOOTING.md` at repo root; a link to it from `README.md`'s `## What's Inside` area and from `using-superpowers/SKILL.md`'s `## Red Flags` area.

- [ ] **Step 1: Compute and verify every anchor slug before writing the file**

For each of the 13 skill files plus the two `subagent-driven-development` sections and the one `writing-skills` SDO section referenced in the design spec, run:

```bash
grep -n '^## ' skills/<name>/SKILL.md
```

and confirm the exact heading text matches what's listed below (this repeats the verification already done for the design spec — do it again here since this is the step that produces the actual committed file):

| Skill | Heading | Anchor |
|---|---|---|
| brainstorming | `## Anti-Pattern: "This Is Too Simple To Need A Design"` | `#anti-pattern-this-is-too-simple-to-need-a-design` |
| compound-learnings | `## Common Mistakes to Avoid` | `#common-mistakes-to-avoid` |
| dispatching-parallel-agents | `## Common Mistakes` | `#common-mistakes` |
| finishing-a-development-branch | `## Red Flags` | `#red-flags` |
| receiving-code-review | `## Common Mistakes` | `#common-mistakes` |
| requesting-code-review | `## Red Flags` | `#red-flags` |
| subagent-driven-development | `## Red Flags` | `#red-flags` |
| subagent-driven-development | `## Durable Progress` | `#durable-progress` |
| subagent-driven-development | `## Model Selection` | `#model-selection` |
| subagent-driven-development | `## Constructing Reviewer Prompts` | `#constructing-reviewer-prompts` |
| systematic-debugging | `## Red Flags - STOP and Follow Process` | `#red-flags---stop-and-follow-process` |
| test-driven-development | `## Red Flags - STOP and Start Over` | `#red-flags---stop-and-start-over` |
| using-git-worktrees | `## Red Flags` | `#red-flags` |
| using-superpowers | `## Red Flags` | `#red-flags` |
| verification-before-completion | `## Red Flags - STOP` | `#red-flags---stop` |
| writing-skills | `## Red Flags - STOP and Start Over` | `#red-flags---stop-and-start-over` |
| writing-skills | `## Anti-Patterns` | `#anti-patterns` |
| writing-skills | `## Skill Discovery Optimization (SDO)` | `#skill-discovery-optimization-sdo` |

If any heading text has since changed, recompute that row's anchor before writing the file (GitHub slug rule: lowercase, strip characters other than letters/digits/spaces/hyphens, replace each space with a hyphen — a literal `-` in the heading plus the space(s) around it becomes a run of hyphens, e.g. `Red Flags - STOP` → `red-flags---stop`).

- [ ] **Step 2: Create `TROUBLESHOOTING.md`**

```markdown
# Troubleshooting

Concrete failure modes this repo has already hit, and where to look when
something goes wrong.

## Cross-Cutting Failure Modes

### Skill descriptions that summarize instead of state triggers

A `description` that summarizes a skill's workflow causes an agent to
follow the description instead of reading the skill body, skipping
steps — reproduced, not hypothetical. A description saying "code review
between tasks" caused an agent to do ONE review even though the skill's
flowchart clearly showed TWO.

See: [`writing-skills/SKILL.md` — Skill Discovery Optimization (SDO)](skills/writing-skills/SKILL.md#skill-discovery-optimization-sdo)

### Conversation memory does not survive compaction

Controllers that lose their place after compaction have re-dispatched
entire completed task sequences — the single most expensive failure
observed in real sessions. Track progress in a ledger file, not only in
todos.

See: [`subagent-driven-development/SKILL.md` — Durable Progress](skills/subagent-driven-development/SKILL.md#durable-progress)

### Silent cost escalation from an omitted model selection

An omitted model when dispatching a subagent inherits the session's
model — often the most capable and most expensive — which silently
defeats deliberate model tiering.

See: [`subagent-driven-development/SKILL.md` — Model Selection](skills/subagent-driven-development/SKILL.md#model-selection)

### Context pollution from pasted history

A dispatch prompt should describe one task, not the session's history.
A real dispatch was observed at 42k characters, 99% of it pasted
prior-task summaries instead of the task at hand.

See: [`subagent-driven-development/SKILL.md` — Constructing Reviewer Prompts](skills/subagent-driven-development/SKILL.md#constructing-reviewer-prompts)

## Per-Skill Red Flags / Common Mistakes

Every skill below documents its own failure modes in full. This is an
index, not a copy — follow the link for the complete section.

- [`brainstorming`](skills/brainstorming/SKILL.md#anti-pattern-this-is-too-simple-to-need-a-design) — Anti-Pattern: "This Is Too Simple To Need A Design"
- [`compound-learnings`](skills/compound-learnings/SKILL.md#common-mistakes-to-avoid) — Common Mistakes to Avoid
- [`dispatching-parallel-agents`](skills/dispatching-parallel-agents/SKILL.md#common-mistakes) — Common Mistakes
- [`finishing-a-development-branch`](skills/finishing-a-development-branch/SKILL.md#red-flags) — Red Flags
- [`receiving-code-review`](skills/receiving-code-review/SKILL.md#common-mistakes) — Common Mistakes
- [`requesting-code-review`](skills/requesting-code-review/SKILL.md#red-flags) — Red Flags
- [`subagent-driven-development`](skills/subagent-driven-development/SKILL.md#red-flags) — Red Flags
- [`systematic-debugging`](skills/systematic-debugging/SKILL.md#red-flags---stop-and-follow-process) — Red Flags - STOP and Follow Process
- [`test-driven-development`](skills/test-driven-development/SKILL.md#red-flags---stop-and-start-over) — Red Flags - STOP and Start Over
- [`using-git-worktrees`](skills/using-git-worktrees/SKILL.md#red-flags) — Red Flags
- [`using-superpowers`](skills/using-superpowers/SKILL.md#red-flags) — Red Flags
- [`verification-before-completion`](skills/verification-before-completion/SKILL.md#red-flags---stop) — Red Flags - STOP
- [`writing-skills`](skills/writing-skills/SKILL.md#red-flags---stop-and-start-over) — Red Flags - STOP and Start Over (plus a separate [Anti-Patterns](skills/writing-skills/SKILL.md#anti-patterns) section)
```

- [ ] **Step 3: Link from README.md**

Read `README.md`'s `## What's Inside` section (currently starting around line 61) and add one line immediately after its heading, before `### Skills Library`:

```markdown
## What's Inside

Hitting a wall? See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for known failure modes.

### Skills Library
```

If the exact surrounding text has drifted from this, use `## What's Inside` as the anchor point and insert the new line directly after it.

- [ ] **Step 4: Link from using-superpowers/SKILL.md**

Read `skills/using-superpowers/SKILL.md`'s `## Red Flags` section and add one line immediately after its heading:

```markdown
## Red Flags

For the full per-skill inventory, see [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md).

These thoughts mean STOP—you're rationalizing:
```

Verify the relative path: `skills/using-superpowers/SKILL.md` is two directories below repo root, so `../../TROUBLESHOOTING.md` is correct — confirm by resolving it manually (`skills/using-superpowers/../../TROUBLESHOOTING.md` → `TROUBLESHOOTING.md`).

- [ ] **Step 5: Verify every link resolves**

For each `skills/*/SKILL.md#anchor` reference in the new file, confirm the anchor's heading really exists:

```bash
grep -c '^## Anti-Pattern: "This Is Too Simple To Need A Design"$' skills/brainstorming/SKILL.md
grep -c '^## Common Mistakes to Avoid$' skills/compound-learnings/SKILL.md
grep -c '^## Common Mistakes$' skills/dispatching-parallel-agents/SKILL.md
grep -c '^## Red Flags$' skills/finishing-a-development-branch/SKILL.md
grep -c '^## Common Mistakes$' skills/receiving-code-review/SKILL.md
grep -c '^## Red Flags$' skills/requesting-code-review/SKILL.md
grep -c '^## Red Flags$' skills/subagent-driven-development/SKILL.md
grep -c '^## Durable Progress$' skills/subagent-driven-development/SKILL.md
grep -c '^## Model Selection$' skills/subagent-driven-development/SKILL.md
grep -c '^## Constructing Reviewer Prompts$' skills/subagent-driven-development/SKILL.md
grep -c '^## Red Flags - STOP and Follow Process$' skills/systematic-debugging/SKILL.md
grep -c '^## Red Flags - STOP and Start Over$' skills/test-driven-development/SKILL.md
grep -c '^## Red Flags$' skills/using-git-worktrees/SKILL.md
grep -c '^## Red Flags$' skills/using-superpowers/SKILL.md
grep -c '^## Red Flags - STOP$' skills/verification-before-completion/SKILL.md
grep -c '^## Red Flags - STOP and Start Over$' skills/writing-skills/SKILL.md
grep -c '^## Anti-Patterns$' skills/writing-skills/SKILL.md
grep -c '^## Skill Discovery Optimization (SDO)$' skills/writing-skills/SKILL.md
```

Expected: every command prints `1`. If any prints `0`, the corresponding heading text (and therefore the anchor used in `TROUBLESHOOTING.md`) has drifted — fix the link before proceeding.

- [ ] **Step 6: Read-through verification**

Read `TROUBLESHOOTING.md`, the modified `README.md` section, and the modified `using-superpowers/SKILL.md` section end-to-end. Confirm:
- No section of any file beyond the intended single-line insertions changed.
- The four cross-cutting entries' summaries accurately reflect their linked source (re-read each linked section and compare).
- `TROUBLESHOOTING.md` doesn't duplicate full paragraphs from any skill file — links only, plus the four one-paragraph summaries.

- [ ] **Step 7: Commit**

```bash
git add TROUBLESHOOTING.md README.md skills/using-superpowers/SKILL.md
git commit -m "Add TROUBLESHOOTING.md as a linked index over per-skill failure modes"
```

---

## Self-Review Notes

- **Spec coverage:** Implements all three design sections (TROUBLESHOOTING.md structure, README link, using-superpowers link) plus the spec's verification requirement (every link target confirmed to resolve).
- **No placeholders:** The task contains complete, literal file contents and the exact anchor-verification commands to run.
- **Ordering:** Single task, no cross-task dependencies. Step 1 (anchor verification) must precede Step 2 (writing the file) since two anchors in the design spec's own draft were already found to be wrong — this plan does not repeat that mistake by skipping re-verification.
- **Drift risk accepted, mitigated:** Per the design spec's non-goals, this file is hand-maintained rather than generated. The mitigation is linking to sections instead of copying them, so a future skill-file edit can only break a link (loud, mechanically checkable via Step 5's commands) rather than silently desynchronizing copied content.
