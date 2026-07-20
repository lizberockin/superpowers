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
