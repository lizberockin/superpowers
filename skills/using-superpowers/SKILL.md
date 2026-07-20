---
name: using-superpowers
description: Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
---

<SUBAGENT-STOP>
If you were dispatched as a subagent to execute a specific task, ignore this skill.
</SUBAGENT-STOP>

<EXTREMELY-IMPORTANT>
If you think there is even a 1% chance a skill might apply to what you are doing, you ABSOLUTELY MUST invoke the skill.

IF A SKILL APPLIES TO YOUR TASK, YOU DO NOT HAVE A CHOICE. YOU MUST USE IT.

This is not negotiable. You cannot rationalize your way out of this.
</EXTREMELY-IMPORTANT>

## The Rule

**Invoke relevant or requested skills BEFORE any response or action** — including clarifying questions, exploring the codebase, or checking files. If it turns out wrong for the situation, you don't have to use it.

**Before entering plan mode:** if you haven't already brainstormed, invoke the brainstorming skill first.

Then announce "Using [skill] to [purpose]" and follow the skill exactly. If it has a checklist, create a todo per item.

## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out. Brainstorming and systematic-debugging are Superpowers' most common process skills, but the rule holds for any of them.

- "Let's build X" → superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

### Full Routing Reference

<!-- BEGIN GENERATED ROUTING TABLE -->
- You MUST use this before any creative work → superpowers:brainstorming
- Use when a problem was just solved, a durable project convention was established, or project-specific vocabulary emerged → superpowers:compound-learnings
- Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies → superpowers:dispatching-parallel-agents
- Use when you have a written implementation plan to execute in a separate session with review checkpoints → superpowers:executing-plans
- Use when implementation is complete, all tests pass, and you need to decide how to integrate the work → superpowers:finishing-a-development-branch
- Use when the user asks for ideas, improvements, surprising options, or AI-generated directions before choosing one to develop → superpowers:ideate
- Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable → superpowers:receiving-code-review
- Use when completing tasks, implementing major features, or before merging to verify work meets requirements → superpowers:requesting-code-review
- Use when executing implementation plans with independent tasks in the current session → superpowers:subagent-driven-development
- Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes → superpowers:systematic-debugging
- Use when implementing any feature or bugfix, before writing implementation code → superpowers:test-driven-development
- Use when starting feature work that needs isolation from current workspace or before executing implementation plans → superpowers:using-git-worktrees
- Use when about to claim work is complete, fixed, or passing, before committing or creating PRs → superpowers:verification-before-completion
- Use when you have a spec or requirements for a multi-step task, before touching code → superpowers:writing-plans
- Use when creating new skills, editing existing skills, or verifying skills work before deployment → superpowers:writing-skills
<!-- END GENERATED ROUTING TABLE -->

## Red Flags

For the full per-skill inventory, see [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md).

These thoughts mean STOP—you're rationalizing:

| Thought | Reality |
|---------|---------|
| "This is just a simple question" | Questions are tasks. Check for skills. |
| "I need more context first" | Skill check comes BEFORE clarifying questions. |
| "Let me explore the codebase first" | Skills tell you HOW to explore. Check first. |
| "I can check git/files quickly" | Files lack conversation context. Check for skills. |
| "Let me gather information first" | Skills tell you HOW to gather information. |
| "This doesn't need a formal skill" | If a skill exists, use it. |
| "I remember this skill" | Skills evolve. Read current version. |
| "This doesn't count as a task" | Action = task. Check for skills. |
| "The skill is overkill" | Simple things become complex. Use it. |
| "I'll just do this one thing first" | Check BEFORE doing anything. |
| "This feels productive" | Undisciplined action wastes time. Skills prevent this. |
| "I know what that means" | Knowing the concept ≠ using the skill. Invoke it. |

## User Instructions

User instructions (CLAUDE.md, AGENTS.md, GEMINI.md, etc, direct requests) take precedence over skills, which in turn override default behavior. Only skip skill workflows or instructions when your human partner has explicitly told you to.
