# Design: Auto-Generate the Skill Catalog from Frontmatter

**Date:** 2026-07-20
**Source:** Survivor idea 1 of [docs/ideation/2026-07-19-onboarding-docs-ideation.md](../../ideation/2026-07-19-onboarding-docs-ideation.md)
**Scope:** A generator script + README.md restructure. Built first on this branch as a prerequisite for idea 5 (routing table expansion), which was deferred pending this project so both surfaces are sourced the same way.

## Problem

`README.md`'s "What's Inside" skill catalog is hand-maintained and currently lists only 14 of the 16 skills that exist under `skills/` — `compound-learnings` and `ideate` are both missing entirely. This is a live, present-tense bug: the catalog's entire job is making skills discoverable, and it is failing at that job today. Every future skill addition risks repeating the same drift unless the catalog is generated from a single source of truth instead of hand-copied.

## Non-goals

- No CI workflow. This repo has no CI pipeline at all (no `.github/workflows`), matching the situation already hit on the CONTRIBUTING.md project. Building CI from scratch is out of scope here; the `--check` mode exists so wiring it into CI later, whenever this repo gets a pipeline, is a one-line addition.
- No new frontmatter fields. The catalog's blurb text comes from each skill's existing `description` field, verbatim — no new `summary` or `category` field is added to any of the 16 `SKILL.md` files.
- No category grouping. The current catalog groups skills into Testing/Debugging/Collaboration/Meta headings, but nothing in frontmatter carries category data, and adding a manifest to carry it would reintroduce the same two-places-to-update drift risk this project exists to eliminate. The generated catalog is a flat, alphabetical list.
- No change to any other part of README.md. The generator's writes are scoped to the content between two marker comments; everything else in the file (How it works, Installation, See it in action, The Basic Workflow, Philosophy, License, telemetry note) is untouched.

## Design

### 1. Generator script: `scripts/generate-skill-catalog.sh`

A bash script, matching the repo's existing `scripts/lint-shell.sh` convention (no new language/tooling dependency).

**Extraction:** For each `skills/*/SKILL.md`, read the YAML frontmatter block (between the first two `---` lines) and extract:
- `name:` — the value after the colon, trimmed
- `description:` — the value after the colon, trimmed, with surrounding double quotes stripped if present (one skill, `brainstorming`, quotes its description in YAML; the rest are unquoted)

Skills are sorted alphabetically by directory name under `skills/` (matching `ls skills/`'s default order).

**Output format:** One markdown bullet per skill: `- **{name}** — {description}`

**Modes:**
- **Default (no flags):** Regenerate the catalog and write it into `README.md` in place, replacing only the content between `<!-- BEGIN GENERATED SKILL CATALOG -->` and `<!-- END GENERATED SKILL CATALOG -->`. Everything outside those markers is untouched.
- **`--check`:** Compute the same generated content but do not write. Compare it against what currently sits between the markers in `README.md`. If identical, exit 0. If different, print a unified diff to stderr and exit 1.

### 2. README.md restructure

The `### Skills Library` subsection changes from category-grouped bullets to a single flat, marker-delimited, alphabetically sorted list:

```markdown
### Skills Library

<!-- BEGIN GENERATED SKILL CATALOG -->
- **brainstorming** — You MUST use this before any creative work - creating features, building components, adding functionality, or modifying behavior. Explores user intent, requirements and design before implementation.
- **compound-learnings** — Use when a problem was just solved, a durable project convention was established, or project-specific vocabulary emerged — captures it as searchable documentation in docs/solutions/ or CONCEPTS.md before the context is lost.
- ...14 more, alphabetical...
<!-- END GENERATED SKILL CATALOG -->
```

No other heading or prose in `## What's Inside` changes.

## Testing / Verification

Unlike the two prior onboarding-docs projects (CONTRIBUTING.md, README worked example), this one ships executable code, so it gets real automated tests, not just a read-through:

- New test file: `tests/skill-catalog/test-generate-skill-catalog.sh`, following the existing bash test-script pattern (`tests/hooks/test-session-start.sh`'s pass/fail-counter, `mktemp -d`, trap-cleanup style).
- Verify extraction against the real `skills/` directory: running the script produces exactly 16 bullets, alphabetically sorted, with `brainstorming`'s quotes stripped and every other skill's description passed through unquoted.
- Verify `--check` exits 0 when `README.md`'s catalog already matches generated output.
- Verify `--check` exits 1 with a non-empty diff when the catalog is stale (test makes a temp copy of `README.md`, corrupts the marked block, runs `--check` against the temp copy — never against the real repo file).
- Verify default mode only modifies content between the markers: run it against a temp copy of `README.md`, confirm every line outside the markers is byte-identical before and after.

## Out of scope for this project (tracked separately)

- Idea 2: Consolidated troubleshooting/FAQ doc (Medium complexity)
- Idea 3: CONTRIBUTING.md + description-skip bug fix — already shipped on the `compound_additions` branch
- Idea 4: README worked example — already shipped on the `compound_additions` branch
- Idea 5: Expand Skill Priority routing table — the reason this project exists; picked back up once this generator ships, reusing the same extraction logic
- Idea 6: Bootstrap CONCEPTS.md (Low complexity, separate project)
- Idea 7: Baseline-test discipline for onboarding docs — explicitly excluded by user request
