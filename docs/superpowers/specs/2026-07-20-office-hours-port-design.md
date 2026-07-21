# Porting gstack's office-hours skill into superpowers (Phase 2a)

## Goal

Port gstack's `office-hours` skill into superpowers as a standalone, dependency-free skill, preserving the actual YC-office-hours methodology (forcing questions, premise challenge, alternatives generation, design doc output) while stripping or translating everything that depends on gstack's private runtime.

## Context

This is a sub-project of [`2026-07-19-gstack-compound-skills-integration-design.md`](2026-07-19-gstack-compound-skills-integration-design.md), which scoped a five-skill port from gstack and compound-engineering into superpowers across three phases. Phase 1 (`compound-learnings`, `ideate`) is complete and merged to `main`. Phase 2 in that spec bundled `office-hours`, `plan-ceo-review`, and `plan-eng-review` together; this spec splits that into **Phase 2a (office-hours, this document)** and **Phase 2b (plan-ceo-review + plan-eng-review, a future spec)**, because each skill's core content alone is comparable in size to all of Phase 1 combined, and office-hours has no prerequisite skill of its own (it's the entry point of the `office-hours → brainstorming → writing-plans` chain), so it can be ported and pressure-tested independently before tackling the two review skills, which share a distinct pattern (the "Prerequisite Skill Offer" — actively invoking a prerequisite skill inline) that doesn't apply to office-hours at all.

The umbrella spec's Decisions (naming, frontmatter contract, the two-tier wiki-then-specs/git-log context step, progressive-disclosure file layout, session-kind collapse) still govern this port. This document records the office-hours-specific calls made on top of those, several of which surfaced only after reading the actual source file — the umbrella spec's Source Inventory characterized gstack's per-skill content at a high level, but didn't anticipate the scale of embedded content (e.g. a 315-line cross-session relationship-tiering system, an AI-image-generation mockup pipeline) that turned out to need its own decision.

## Source file assessment

`office-hours/SKILL.md` in gstack is 1697 lines; its one on-demand section file, `sections/design-and-handoff.md`, is 584 lines. Roughly 800 lines of the SKILL.md (everything between "Preamble (run first)" and "SETUP") is gstack's shared, resolver-injected runtime boilerplate — identical in shape across every gstack skill (confirmed by diffing against `plan-eng-review/SKILL.md`, and by gstack's own `CLAUDE.md`, which documents these as generated blocks from `scripts/resolvers/*.ts`). This is exactly what the umbrella spec's Decisions 3/4/8 already call out to strip; no new decisions were needed there.

The remaining ~900 lines (roughly half the SKILL.md, plus all of the section file) split into three buckets, detailed in Decisions below.

## Decisions

1. **Scope for this spec: office-hours only.** `plan-ceo-review` and `plan-eng-review` are deferred to a Phase 2b spec. Reusable patterns from this port (frontmatter normalization, the wiki-context step, the visual-companion translation) carry forward to that spec, but the "Prerequisite Skill Offer" pattern — where the review skills read and inline-execute `office-hours`'s SKILL.md, skipping a named list of shared sections — is entirely Phase 2b's concern and is not addressed here.

2. **Naming and file layout.** Skill name stays `office-hours` (per the umbrella spec's Decision 2 — no rename, no collision). Layout is flat: `skills/office-hours/SKILL.md` + `skills/office-hours/design-and-handoff.md`, no `sections/` subfolder, no `manifest.json`. The umbrella spec's Decision 5 describes keeping gstack's manifest+sections pattern, but its own Migration Plan already qualifies this by file count ("flat next to SKILL.md if 1-2 files") — office-hours has exactly one section file, so a one-row passive registry pointing at a single file adds a layer of indirection with no payoff. This matches existing superpowers precedent: single supporting files stay flat (`requesting-code-review/code-reviewer.md`, `writing-plans/plan-document-reviewer-prompt.md`), and the SKILL.md's own "Section index" table already tells the reader when to read `design-and-handoff.md` — a manifest.json would just restate that.

3. **Frontmatter.** Collapse to `name` + `description` only. Rewrite the description in third-person "Use when..." form per `writing-skills`, matching the style established by `compound-learnings`/`ideate` in Phase 1. Drop `preamble-tier`, `version`, `allowed-tools`, `triggers`, `gbrain` (per the umbrella spec's Decision 3).

4. **Context-gathering translation.** The source's `Brain Context (preflight)`, `Prior Learnings` (with its cross-project-learnings config toggle), and `Phase 2.5: Related Design Discovery` (a grep across `~/.gstack/projects/{slug}/*-design-*.md`) all collapse into the umbrella spec's Decision 4 two-tier context step: search `docs/solutions/` + `CONCEPTS.md` first, fall back to `docs/superpowers/specs/` + `git log --oneline -20`. The cross-project toggle is dropped outright — the wiki is per-repo by design, so there's no cross-project mode to have an opinion about.

5. **Visual handling.** The source has two visual layers, both hard-dependent on gstack-proprietary binaries: `Visual Design Exploration` (three AI-generated mockup variants via gstack's GPT-image-API binary, plus a comparison-board server) and its fallback, `Visual Sketch` (a rough wireframe rendered via gstack's headless-browser binary). Neither binary exists outside gstack's install, and porting an image-generation pipeline is out of scope (the umbrella spec already rules out porting gstack's CLIs generally). The AI-mockup-variants layer is dropped entirely with no replacement. The wireframe-sketch layer's *intent* — show a rough visual, gather feedback, iterate — maps directly onto `brainstorming`'s existing Visual Companion mechanism (offered just-in-time, per-question, browser-tab-based). The ported office-hours reuses that mechanism directly (points at `skills/brainstorming/visual-companion.md` rather than duplicating its server/script code) instead of building a second, redundant visual-rendering path.

6. **Cross-model second opinion — ported near-verbatim.** `Phase 3.5: Cross-Model Second Opinion` and `Step 6: Outside design voices` both check for a `codex` binary and, when absent (or on error), fall back to dispatching a Claude subagent via the `Agent` tool for genuine independent review. This is already exactly the portable pattern superpowers uses natively — no translation needed beyond generalizing the hardcoded `~/.claude/skills/gstack/...` filesystem-boundary warning path in the codex prompt to a generic "don't read Claude Code skill definition directories" warning.

7. **Spec Review Loop — ported as-is.** The source's adversarial-subagent review of the design doc (dispatch a fresh-context reviewer via the `Agent` tool, score on five dimensions, fix and re-dispatch up to 3 iterations, a convergence guard to stop infinite disagreement loops, persist unresolved issues as a "Reviewer Concerns" section) is genuinely good, portable, self-contained content — distinct from `brainstorming`'s own inline spec self-review, since it reviews office-hours's own design-doc deliverable rather than a plan. Ported unchanged except for stripping the `~/.gstack/analytics/spec-review.jsonl` metrics-append line.

8. **Learning capture.** The source's `Capture Learnings` step and its "Eureka" logging both call `gstack-learnings-log`, a CLI with no superpowers equivalent. Drop the CLI calls; keep the *behavior* (name the insight to the user when one surfaces) but end the session with a plain note pointing at `compound-learnings` as where to capture it if it's a genuine, reusable discovery — consistent with the umbrella spec's wiki-consultation table entry for `finishing-a-development-branch` (a write-side hookup at the moment context is freshest).

9. **Phase 6 handoff — drop relationship tiering, keep one prose line.** The source's `Phase 6: Handoff` is 315 of the section file's 584 lines, almost all of it a cross-session relationship-tiering system (`introduction`/`welcome_back`/`regular`/`inner_circle` tiers, keyed off a `builder-profile.jsonl` that tracks session count across every repo a user has ever run gstack in). The umbrella spec's Decision 4 already rules `builder-profile.jsonl` out as genuinely gstack-specific and not recoverable — this is that ruling applied concretely. What's left after removing the tiering is a "next-skill recommendation" block that, in the source, actively auto-launches the next review skill via an AskUserQuestion-driven decision brief and the `Skill` tool. Per the hand-off style decided below (Decision 10), this collapses to a single prose line at the end: "Design doc saved at `<path>`. Next: invoke `brainstorming` to turn this into an implementation-ready design." No tiering, no auto-launch, no reference to `plan-ceo-review`/`plan-eng-review` (they don't exist in superpowers yet — that line can be extended once Phase 2b lands).

10. **Hand-off style: prose only, no active invocation.** Unlike `brainstorming`, whose terminal state is a hard rule to invoke `writing-plans` directly, ported `office-hours` only *mentions* `brainstorming` as the next step and lets the user decide when to continue. This keeps office-hours self-contained (usable standalone, without triggering a chain) and matches the umbrella spec's original Decision 3 (`benefits-from` → prose, not a new frontmatter field or forced invocation).

11. **Drop entirely, no replacement.** `Brain Calibration Write-Back` and `Brain Cache Background Refresh` — both depend on gbrain MCP operations (`mcp__gbrain__takes_add`, cache-invalidation calls) with no superpowers equivalent and no plausible lightweight substitute. Building one is out of scope for this port.

12. **Core methodology — ported verbatim, no translation.** `Phase 2A: Startup Mode` (the six YC forcing questions), `Phase 2B: Builder Mode`, `Phase 2.75: Landscape Awareness` (pure WebSearch + three-layer synthesis, already infra-free), `Phase 3: Premise Challenge`, `Phase 4: Alternatives Generation`, `Phase 4.5: Founder Signal Synthesis`, both design-doc templates (Startup and Builder mode), and `Important Rules` (never implement, one question at a time, mandatory real-world assignment) are the actual skill content this port exists to preserve. No gstack dependency in any of these — ported unchanged.

## What ships

```
skills/office-hours/
  SKILL.md              # name+description frontmatter, Phase 2A/2B/2.75/3/4/4.5,
                         # translated context-gathering step, translated visual step,
                         # cross-model second opinion, "See also" line for brainstorming
  design-and-handoff.md # design doc templates, Spec Review Loop, single-line next-step handoff
```

## Pressure-testing plan

Per `writing-skills`' TDD methodology: dispatch a subagent to run the newly-authored `office-hours` end-to-end against two fabricated scenarios (one Startup-mode idea, one Builder-mode idea) and confirm:

- No dangling `gstack`/`~/.gstack`/`gstack-*` CLI references survive anywhere in the ported files.
- The `codex`-unavailable path correctly falls back to the `Agent` tool for both the cross-model second opinion and the outside-design-voices step.
- The Visual Companion offer fires only when the chosen approach is UI-shaped, and is silently skipped for backend-only ideas.
- The context-gathering step degrades gracefully when `docs/solutions/` doesn't exist yet (empty repo, no wiki adopted).
- The design doc gets written to disk, survives the Spec Review Loop's adversarial pass, and the session ends with the single prose next-step line — no auto-launch, no tiering artifacts.

This mirrors the umbrella spec's Migration Plan Phase 2 step 4 (pressure-test each rewritten skill before merging), scoped to office-hours alone.

## Explicitly out of scope (for this spec)

- `plan-ceo-review`, `plan-eng-review`, and the "Prerequisite Skill Offer" active-invocation pattern — Phase 2b.
- Any form of AI-image-generation mockup pipeline (out of scope per the umbrella spec's stance on gstack's proprietary CLIs).
- Cross-session personalization / relationship tiering of any kind.
- Wiki-consultation retrofits to other existing superpowers skills (systematic-debugging, writing-plans, brainstorming, etc.) — these remain Phase 3 of the umbrella spec, unaffected by this document.
