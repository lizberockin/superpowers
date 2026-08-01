# plan-ceo-review / plan-eng-review port — status + next steps

## Current state

`skills/plan-ceo-review/` and `skills/plan-eng-review/` were copied from gstack
and partially ported per
`docs/superpowers/specs/2026-07-20-plan-ceo-eng-review-port-design.md`.

Done (spec decisions 2, 3, 5, 6, 7, 9, 13):

- Frontmatter stripped to name/description
- Shared gstack runtime boilerplate deleted (preamble, AskUserQuestion Format, etc.)
- Context gathering rewired to the wiki-then-specs/git-log pattern
- Design Doc Check rewritten as a three-step gate, Prerequisite Skill Offer
  now actively invokes office-hours
- Landscape Check (CEO) inlined, ETHOS.md dependency dropped
- Cross-Model Second Opinion (Outside Voice rename) matches office-hours'
  Phase 3.5 pattern

**Not done** — both `SKILL.md` and `review-sections.md` in each skill still
call gstack binaries that don't exist in this repo and write to
`~/.gstack/projects/...`:

- Decision 8 — Review Readiness Dashboard still references the 8-skill
  gstack dashboard and `gstack-review-log`/`gstack-decision-log`/
  `gstack-review-read`; needs to become the minimal per-plan-file
  `## CEO Plan Review` / `## Eng Plan Review` section described in the spec
- Decision 10 — TODOS.md write-up mostly fine, but a stray
  `~/.gstack/projects/` reference remains (plan-ceo-review review-sections.md
  line ~786)
- Decision 11 — CEO Plan artifact still writes to
  `~/.gstack/projects/$SLUG/ceo-plans/` via `gstack-slug`; needs to move to
  `docs/superpowers/ceo-plans/{date}-{feature-slug}.md`, drop the archive step
- Decision 12 — JSONL artifact for `/autoplan` still present in both
  review-sections.md files; needs to be dropped (no reader exists in
  superpowers)
- Decision 14 — worktree parallelization section (eng only) needs the
  `superpowers:using-git-worktrees` cross-reference added
- Decision 15 — Capture Learnings still calls `gstack-learnings-log`; needs
  to point at `compound-learnings` instead
- Also stray gstack refs to clean up: `gstack-config`, `gstack-brain-cache`
  invalidate/refresh calls, `gstack-analytics` JSONL logging in SKILL.md
  (lines ~439-440 in plan-ceo-review/SKILL.md)

## Why this branch exists

These two skills are functional for their core review methodology but will
silently no-op or fail on the write-back/dashboard/analytics steps above,
since the gstack binaries they shell out to aren't part of this repo. Nothing
else in superpowers references or depends on these two skills (confirmed via
grep across README, routing table, office-hours) — so this is scoped,
self-contained WIP, not a repo-wide blocker.

`add_gstack` was split: the completed office-hours port + this design spec
doc were cut into a separate branch (based at commit `e0dae20`) for merging
into `main`. This branch (`plan-ceo-eng-review-wip`) carries the rest —
resume here.

## Next steps

1. Work through Decisions 8, 10 (remaining stray ref), 11, 12, 14, 15 above,
   same pattern as the already-applied decisions (one commit per decision,
   matching the commit history on this branch).
2. Re-run `grep -rn "gstack" skills/plan-ceo-review skills/plan-eng-review`
   until it returns nothing.
3. Merge/rebase onto whatever `main` looks like after the office-hours branch
   lands.
