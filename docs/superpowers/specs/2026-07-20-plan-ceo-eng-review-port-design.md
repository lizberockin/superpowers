# Phase 2b: Porting plan-ceo-review + plan-eng-review — Design Spec

This is Phase 2b of the gstack → superpowers compound-skills integration
(see `docs/superpowers/specs/2026-07-19-gstack-compound-skills-integration-design.md`).
Phase 2a ported `office-hours` and established the translation playbook this
spec reuses throughout. Both `plan-ceo-review` and `plan-eng-review` are
ported together in one spec/plan, since they share the large majority of
their gstack-boilerplate-removal and mechanism-translation decisions.

## What these skills do

- **plan-ceo-review**: a strategic plan review with four modes (SCOPE
  EXPANSION, SELECTIVE EXPANSION, HOLD SCOPE, SCOPE REDUCTION) and 11 review
  sections (Architecture, Error & Rescue Map, Security & Threat Model, Data
  Flow & Edge Cases, Code Quality, Test Review, Performance, Observability,
  Deployment & Rollout, Long-Term Trajectory, Design & UX).
- **plan-eng-review**: a narrower "lock in the execution plan" review with 4
  sections (Architecture, Code Quality, Test Review, Performance).

Both interactively walk the user through findings one AskUserQuestion call
at a time — never batching, never silently writing a fix into the plan
without approval.

## Decision 1: Scope and file layout

Port both skills together, one spec, one implementation plan. Flat layout,
matching office-hours' precedent:

- `skills/plan-ceo-review/SKILL.md` + `skills/plan-ceo-review/review-sections.md`
- `skills/plan-eng-review/SKILL.md` + `skills/plan-eng-review/review-sections.md`

No `manifest.json`/`references/` subfolder — each skill has exactly one
supporting file, well under the threshold for nesting.

## Decision 2: Frontmatter

Strip to `name`/`description` only. Drop `preamble-tier`, `interactive`,
`version`, `allowed-tools`, `triggers`, `benefits-from`, `gbrain`. Trigger
phrases fold into the description in "Use when..." form, per
`writing-skills` convention (same treatment as office-hours Decision 4).

`benefits-from: [office-hours]` becomes a prose "See also" line in both
skills' bodies, plus a reciprocal "companion review" mention between
plan-ceo-review and plan-eng-review. gstack's CEO-before-eng ordering
convention (used in its `autoplan` pipeline) survives as a suggestion in
prose, not an enforced order.

## Decision 3: Boilerplate removal

Every shared gstack runtime block is deleted entirely — same treatment as
office-hours Decisions 3/8/13:

- Preamble (run first) script
- Plan Mode Safe Operations / Skill Invocation During Plan Mode
- First-run guidance
- Skill-routing CLAUDE.md injection block
- Vendored-gstack migration warning
- Spawned-session behavior
- **AskUserQuestion Format** (the D-numbering/ELI10/Completeness-score/
  Conductor-host-branching block) — confirmed gstack-coupled (feeds
  `/plan-tune`'s auto-decide system via `gstack-question-log`), not generic
  Claude Code guidance. Every dangling reference to this deleted section
  (both SKILL.md files' Step 0 sections, both review-sections.md files' per-
  section STOP lines and CRITICAL RULE blocks) is replaced with a plain
  "call AskUserQuestion directly" instruction.
- Artifacts Sync / gbrain wiring
- Model-Specific Behavioral Patch (claude)
- Voice
- Writing Style / `explain_level` tiering
- Completeness Principle — Boil the Ocean
- Confusion Protocol
- Continuous Checkpoint Mode
- Context Health
- Question Tuning
- Repo Ownership
- Completion Status Protocol
- Operational Self-Improvement
- Telemetry
- Plan Status Footer
- Context Recovery (gstack-artifact-coupled: `~/.gstack/projects/.../ceo-plans`,
  `checkpoints`, `timeline.jsonl`, `decisions.active.json`)
- Brain Context (preflight)
- Prior Learnings' CLI wiring (`gstack-learnings-search`)
- Brain Calibration Write-Back
- Brain Cache Background Refresh
- Review Log's `gstack-review-log`/`gstack-decision-log` calls

eng's Step 0 Scope Challenge also has a dangling reference to the (deleted)
preamble's "Search Before Building" section — replaced with an inline
one-liner restating the check in place.

## Decision 4: Core review methodology — ported near-verbatim

The actual value of these skills survives unchanged in substance:

- CEO's 4 modes and Step 0 Nuclear Scope Challenge (0A Premise Challenge,
  0B Existing Code Leverage, 0C Dream State Mapping, 0C-bis Implementation
  Alternatives, 0D-prelude Expansion Framing, 0D Mode-Specific Analysis, 0E
  Temporal Interrogation, 0F Mode Selection)
- CEO's 11 review sections in full (including their ASCII-diagram and
  error-rescue-table requirements)
- eng's Scope gate (hard STOP) + Step 0 Scope Challenge (existing-code
  leverage, minimum-change, complexity check, search check, TODOS
  cross-reference, distribution check)
- eng's 4 review sections, Confidence Calibration + pre-emit verification
  gate, Test Framework Detection, E2E Test Decision Matrix, REGRESSION RULE
- Anti-skip / Anti-shortcut rules and the AskUserQuestion-per-issue gating
  discipline (never batch findings; an "obvious fix" still needs approval)
- Cognitive Patterns, PRE-REVIEW SYSTEM AUDIT, Frontend/UI Scope Detection,
  Taste Calibration, Retrospective Check/learning (confirmed gstack-free
  despite the name — pure `git log` analysis)
- EXIT PLAN MODE GATE blocking checklist (rewired to reference the renamed
  Plan Review Report — see Decision 8 — instead of `GSTACK REVIEW REPORT`)

## Decision 5: Context gathering

Replaces Brain Context (preflight) and Prior Learnings with the same
two-tier wiki approach established in office-hours Decision 6:
`docs/solutions/` + `CONCEPTS.md` primary, `docs/superpowers/specs/` +
`docs/superpowers/plans/` + `git log --oneline -20` fallback. The
cross-project learnings toggle is dropped — the wiki is per-repo, so
there's no cross-project mode to have an opinion about.

## Decision 6: Design Doc Check (three-step gate)

1. Check the standard location: `docs/superpowers/office-hours/*.md`,
   lineage detected via the `Branch:` header inside the file (same
   convention office-hours itself uses — not filename-encoded, unlike
   gstack's original `*-$BRANCH-design-*.md` glob).
2. If not found, ask the user directly whether a design doc already exists
   somewhere else, and let them point to a path.
3. If still not found, offer to actively invoke `office-hours` via the
   Skill tool (see Decision 9 for why this is active, not prose-only).

## Decision 7: Cross-Model Second Opinion (renamed from "Outside Voice")

Same mechanics as office-hours' Phase 3.5, applied to both skills:

- Opt-in — ask once via AskUserQuestion, matching office-hours' pattern
  (not gstack's default-on).
- Plain `command -v codex` availability check (not gstack's
  binary-backed `gstack-codex-probe`).
- Prompt written to a temp file before invocation — fixes a real
  shell-injection exposure the source had (it embedded plan text, up to
  30KB, directly in a `codex exec "<prompt>"` string). office-hours already
  carries this fix; these two skills' Outside Voice never had it.
- Generalized filesystem-boundary warning (drops the gstack-specific
  `agents/openai.yaml` mention).
- 5-minute timeout, auth/timeout/empty-response error triad, Agent-tool
  fallback, verbatim-output presentation — all ported as-is from
  office-hours' pattern.

## Decision 8: Review Readiness / Plan Review Report

Renamed from `GSTACK REVIEW REPORT`. The source's 8-skill ASCII dashboard
(Eng Review / CEO Review / Design Review / Adversarial / Outside Voice
rows, etc.) is dropped — 6 of its 8 data sources aren't being ported, so
it would render mostly blank. Replaced with a minimal derived check: each
skill writes its own report as the plan file's terminal `## ` section —
plan-ceo-review writes/overwrites `## CEO Plan Review`, plan-eng-review
writes/overwrites `## Eng Plan Review` — and checks for that same heading
on entry to know whether a review already ran on this plan. No separate
persistent log store (`gstack-review-log`) is needed; the plan file is its
own readiness record. Write mechanics (detect the active plan-mode plan
file, delete-then-append the terminal section, verify via re-read, never
edit mid-file) are unchanged — that part was never gstack-coupled.

## Decision 9: Prerequisite Skill Offer — active invocation

gstack's mechanism (read office-hours' raw SKILL.md, skip a named list of
12 sections) is broken as a literal port: none of the 12 section names in
its skip-list exist in ported office-hours' actual structure (`Phase 1`,
`Phase 2A/2B`, `Phase 2.5`, etc.), since that skill's own boilerplate was
already stripped in Phase 2a.

Resolution: when the user opts in (per Decision 6 step 3), actively invoke
`superpowers:office-hours` via the Skill tool and let it run to full
completion — no skip-list needed, since it has no boilerplate left to
double-execute. Resume the review once it's done.

This is a deliberate exception to Decision 12's "no active invocation at
completion" pattern from the office-hours spec: that pattern governs
end-of-skill handoffs (respecting user pacing on what to do *next*), while
this is a pre-work prerequisite gate the user has already opted into. The
two situations aren't in tension.

## Decision 10: New artifact — TODOS.md

New repo-root convention. Simple checklist, no gstack's schema file:

```
- [ ] <item> — <reason> — source: plan-ceo-review/plan-eng-review finding (<date>)
```

Both review skills write to it. office-hours' Phase 1 already opportunistically
reads a TODOS.md if present (read-only, unchanged) — this closes that loop
by giving it something to find.

## Decision 11: New artifact — CEO Plan

CEO-only. Writes to `docs/superpowers/ceo-plans/{date}-{feature-slug}.md`
(Vision, 10x Check, Platonic Ideal, Scope Decisions, Accepted Scope,
Deferred-to-TODOS.md). Two simplifications from the source:

- No archival-to-`archive/` step for stale plans — these are git-committed
  markdown files, so `git log` already gives full history without a
  parallel archive-folder mechanism.
- No separate "promote to `docs/designs`" step — the file is already
  git-committed by default, so there's nothing to promote.

## Decision 12: Implementation Tasks — drop the JSONL artifact

Both skills' "Required Outputs" write a Markdown checklist (kept, ported
as-is) and a JSONL artifact via `jq` (dropped). The JSONL's sole documented
consumer is `/autoplan`, which isn't in scope for this port — no reader
exists for it in superpowers.

## Decision 13: Landscape Check (CEO only)

Inlines the three-layer synthesis (Layer 1 tried-and-true / Layer 2
new-and-popular / Layer 3 first-principles) directly in the skill body,
mirroring office-hours' own Phase 2.75: Landscape Awareness — no dependency
on gstack's proprietary `ETHOS.md`.

## Decision 14: Worktree parallelization strategy (eng only)

Kept as-is (already generic, already names "Claude Code's Agent tool with
`isolation: \"worktree\"`" directly) — with an added explicit cross-reference
to `superpowers:using-git-worktrees` for how to actually set up the
isolated workspace per parallel lane it identifies.

## Decision 15: Capture Learnings

Rewritten to point at `compound-learnings`, dropping the
`gstack-learnings-log` CLI call — same treatment as office-hours Decision 10.

## Decision 16: Handoff

Completion messaging stays prose-only — no active invocation of the next
skill at completion (consistent with Decision 12 of the office-hours spec).
The Prerequisite Skill Offer (Decision 9 above) is the one exception,
since it's a pre-work gate, not a completion handoff.

## Explicitly out of scope

- gstack's `/autoplan`, `/plan-design-review`, `/adversarial-review`,
  `/codex-review`/`/codex-plan-review`, `/review` — not being ported. Any
  mechanism whose sole reason for existing was feeding one of these (the
  JSONL task artifact, the 8-skill Review Readiness Dashboard) is dropped
  rather than translated.
- Any further expansion of `plan-ceo-review`'s scope-expansion modes beyond
  what's already in the source (e.g. deeper `docs/designs`-equivalent
  publishing workflows) — out of scope, revisit only if a real gap is felt
  in practice.
