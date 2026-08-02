# Design: Consolidated Troubleshooting / FAQ Doc

**Date:** 2026-07-20
**Source:** Survivor idea 2 of [docs/ideation/2026-07-19-onboarding-docs-ideation.md](../ideation/2026-07-19-onboarding-docs-ideation.md)
**Scope:** New `TROUBLESHOOTING.md` at repo root, plus one link each from `README.md` and `skills/using-superpowers/SKILL.md`.

## Problem

13 of the repo's 16 skill files carry their own Red Flags / Common Mistakes / Anti-Pattern section, in three different heading conventions (`## Red Flags`, `## Common Mistakes`, `## Anti-Pattern(s)`) and inconsistent internal shapes (tables, bullet lists, bold-prefixed rationalization phrases). A reader or agent hitting a wall has no single place to look — they must already know which skill's file might contain the relevant section. No standalone troubleshooting surface exists anywhere in the repo today.

**Verified inventory** (`grep -rniE '^#+\s*(red flags?|anti.?patterns?|common mistakes?)' skills/*/SKILL.md`): `dispatching-parallel-agents`, `compound-learnings`, `brainstorming`, `requesting-code-review`, `using-git-worktrees`, `receiving-code-review`, `test-driven-development`, `finishing-a-development-branch`, `writing-skills`, `systematic-debugging`, `subagent-driven-development`, `verification-before-completion`, `using-superpowers` — 13 files. `executing-plans`, `ideate`, `writing-plans` have none.

## Non-goals

- **No mechanical generator script**, unlike ideas 1 and 5. Those extracted single-line frontmatter fields into a uniform bullet format; this content is free-form markdown in three different heading conventions and shapes (tables vs. bullets vs. bold-prefixed prose) — mechanical extraction would either break on the inconsistency or produce a low-quality, decontextualized dump (e.g. `requesting-code-review`'s "If reviewer wrong" bullets sit under its `## Red Flags` heading but aren't themselves a red flag). This project is a hand-curated index instead.
- **No content forking.** `TROUBLESHOOTING.md` links to each skill's existing section by anchor rather than copying its text. This is the drift mitigation the ideation doc's "Downsides" section called for ("unless it transcludes or is generated rather than hand-copied") — a link can't drift out of sync with the section it points to; only a renamed heading breaks it, which is a normal doc-maintenance concern rather than a generator problem.
- **No CI wiring**, matching every prior project on this branch.
- **No resolution of the four failure-mode entries beyond what's already documented.** Each of the four seeded entries below quotes and links existing, verified repo content — none is new claims invented for this doc.

## Resolving the open tension (centralize vs. distribute)

The ideation doc flagged idea 2 (centralize into one doc) as in direct tension with rejected alternative M13 (distribute warnings to the point of failure inside each skill) — both resting on the same evidence, pulling opposite directions. This design doesn't pick one side outright: `TROUBLESHOOTING.md` is a **linked index, not a transclusion**. A reader gets the "one place to look" discoverability idea 2 wanted, but clicking through lands them on the full section in its original skill file — the same point-of-failure locality M13 wanted preserved. Centralizing the *index* while distributing the *content* keeps both properties without needing a synchronization mechanism.

## Design

### 1. `TROUBLESHOOTING.md` structure

```markdown
# Troubleshooting

Concrete failure modes this repo has already hit, and where to look when
something goes wrong.

## Cross-Cutting Failure Modes

### Skill descriptions that summarize instead of state triggers
A `description` that summarizes a skill's workflow causes an agent to
follow the description instead of reading the skill body, skipping
steps — reproduced, not hypothetical.
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

Exact anchor slugs are verified against each file's actual heading text during implementation (Task 1), not assumed from this draft.

### 2. Link from `README.md`

Add one line under `## What's Inside` (before or after the skill catalog — exact placement decided during implementation by reading the current file), e.g.:

```markdown
Hitting a wall? See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for known failure modes.
```

### 3. Link from `skills/using-superpowers/SKILL.md`

Add one line near the existing `## Red Flags` section (which stays otherwise unchanged), pointing to the consolidated doc for the full per-skill inventory:

```markdown
For the full per-skill inventory, see [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md).
```

(Relative path verified against the file's actual depth during implementation.)

## Testing / Verification

Documentation-only change, no executable behavior — verification is a read-through plus a mechanical link check:

- Every link target in `TROUBLESHOOTING.md` resolves — run a link-check pass confirming each `skills/*/SKILL.md#anchor` reference matches a real heading in that file (by grepping the heading text and confirming the kebab-case slug matches the anchor used).
- Read `TROUBLESHOOTING.md` end-to-end for tone and accuracy against the four quoted source sections.
- Confirm the `README.md` and `using-superpowers/SKILL.md` edits are single-line additions that don't disturb surrounding content (the routing-table markers added by idea 5, the worked-example section added by idea 4, etc.).

## Out of scope for this project (tracked separately)

- Idea 6: Bootstrap CONCEPTS.md — explicitly skipped per user decision (format mismatch: CONCEPTS.md is domain-noun vocabulary, not bug/decision history; the three landmines idea 6 named belong in `docs/solutions/`, not raised again here).
- Idea 7: Baseline-test discipline — explicitly excluded by user request.
