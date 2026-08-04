# Superpowers

Superpowers is a complete software development methodology for your coding agent, built on top of a set of composable skills and some initial instructions that make sure your agent uses them.

## How it works

It starts from the moment you fire up your coding agent. As soon as it sees that you're building something, it *doesn't* just jump into trying to write code. Instead, it steps back and asks you what you're really trying to do. 

Once it's teased a spec out of the conversation, it shows it to you in chunks short enough to actually read and digest. 

After you've signed off on the design, your agent puts together an implementation plan that's clear enough for an enthusiastic junior engineer with poor taste, no judgement, no project context, and an aversion to testing to follow. It emphasizes true red/green TDD, YAGNI (You Aren't Gonna Need It), and DRY. 

Next up, once you say "go", it launches a *subagent-driven-development* process, having agents work through each engineering task, inspecting and reviewing their work, and continuing forward. It's not uncommon for your agent to work autonomously for a couple hours at a time without deviating from the plan you put together.

There's a bunch more to it, but that's the core of the system. And because the skills trigger automatically, you don't need to do anything special. Your coding agent just has Superpowers.

## Installation

Superpowers is available via the [official Claude plugin marketplace](https://claude.com/plugins/superpowers):

```bash
/plugin install superpowers@claude-plugins-official
```

Or via the Superpowers marketplace:

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

Both marketplaces install the identical plugin; pick whichever you already have configured.

## See it in action

> "Let's build a rate limiter for the API"

Agent: *Using brainstorming to explore the rate limiter design...*

[asks clarifying questions, proposes approaches, presents a
design for approval — before any code gets written]

## The Basic Workflow

1. **brainstorming** - Activates before writing code. Refines rough ideas through questions, explores alternatives, presents design in sections for validation. Saves design document.

2. **using-git-worktrees** - Activates after design approval. Creates isolated workspace on new branch, runs project setup, verifies clean test baseline.

3. **writing-plans** - Activates with approved design. Breaks work into bite-sized tasks (2-5 minutes each). Every task has exact file paths, complete code, verification steps.

4. **subagent-driven-development** or **executing-plans** - Activates with plan. Dispatches fresh subagent per task with two-stage review (spec compliance, then code quality), or executes in batches with human checkpoints.

5. **test-driven-development** - Activates during implementation. Enforces RED-GREEN-REFACTOR: write failing test, watch it fail, write minimal code, watch it pass, commit. Deletes code written before tests.

6. **requesting-code-review** - Activates between tasks. Reviews against plan, reports issues by severity. Critical issues block progress.

7. **finishing-a-development-branch** - Activates when tasks complete. Verifies tests, presents options (merge/PR/keep/discard), cleans up worktree.

**The agent checks for relevant skills before any task.** Mandatory workflows, not suggestions.

## What's Inside

Hitting a wall? See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for known failure modes.

### Skills Library

<!-- BEGIN GENERATED SKILL CATALOG -->
- **brainstorming** — You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.
- **compound-learnings** — Use when a problem was just solved, a durable project convention was established, or project-specific vocabulary emerged - captures it as searchable documentation in docs/solutions/ or CONCEPTS.md before the context is lost.
- **compound-memory** — Use when the user signals the session is wrapping up - checks whether anything worth remembering was never saved to Claude Code's Auto Memory.
- **dispatching-parallel-agents** — Use when facing 2+ independent tasks that can be worked on without shared state or sequential dependencies
- **executing-plans** — Use when you have a written implementation plan to execute in a separate session with review checkpoints
- **finishing-a-development-branch** — Use when implementation is complete, all tests pass, and you need to decide how to integrate the work - guides completion of development work by presenting structured options for merge, PR, or cleanup
- **ideate** — Use when the user asks for ideas, improvements, surprising options, or AI-generated directions before choosing one to develop - generates and evaluates grounded ideas via parallel research subagents. Use brainstorming instead to refine an idea the user already has in mind.
- **office-hours** — Use when the user has a new product/project idea, asks whether something is worth building, wants to think through design decisions for something that doesn't exist yet, or is exploring a concept before any code is written - proactively invoke rather than answering directly. Two modes: Startup mode runs six YC-style forcing questions (demand reality, status quo, desperate specificity, narrowest wedge, observation, future-fit); Builder mode is design-thinking brainstorming for side projects, hackathons, learning, and open source. Produces a design doc, never code.
- **receiving-code-review** — Use when receiving code review feedback, before implementing suggestions, especially if feedback seems unclear or technically questionable - requires technical rigor and verification, not performative agreement or blind implementation
- **requesting-code-review** — Use when completing tasks, implementing major features, or before merging to verify work meets requirements
- **subagent-driven-development** — Use when executing implementation plans with independent tasks in the current session
- **systematic-debugging** — Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes
- **test-driven-development** — Use when implementing any feature or bugfix, before writing implementation code
- **using-git-worktrees** — Use when starting feature work that needs isolation from current workspace or before executing implementation plans - ensures an isolated workspace exists via native tools or git worktree fallback
- **using-superpowers** — Use when starting any conversation - establishes how to find and use skills, requiring skill invocation before ANY response including clarifying questions
- **verification-before-completion** — Use when about to claim work is complete, fixed, or passing, before committing or creating PRs - requires running verification commands and confirming output before making any success claims; evidence before assertions always
- **writing-plans** — Use when you have a spec or requirements for a multi-step task, before touching code
- **writing-skills** — Use when creating new skills, editing existing skills, or verifying skills work before deployment
<!-- END GENERATED SKILL CATALOG -->

## Philosophy

- **Test-Driven Development** - Write tests first, always
- **Systematic over ad-hoc** - Process over guessing
- **Complexity reduction** - Simplicity as primary goal
- **Evidence over claims** - Verify before declaring success

## License

MIT License - see LICENSE file for details

## Visual companion telemetry

By default, the logo on brainstorming's optional visual companion feature is loaded from a remote website, which includes the version of Superpowers in use but nothing about your project, prompt, or coding agent. To disable this, set the environment variable `SUPERPOWERS_DISABLE_TELEMETRY` to any true value. Superpowers also honors Claude Code's `DISABLE_TELEMETRY` and `CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC` opt-outs.
