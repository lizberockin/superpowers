# Design: Expand the Skill Priority Routing Table to Full Coverage

**Date:** 2026-07-20
**Source:** Survivor idea 5 of [docs/ideation/2026-07-19-onboarding-docs-ideation.md](../../ideation/2026-07-19-onboarding-docs-ideation.md)
**Scope:** `skills/using-superpowers/SKILL.md` only. Depends on idea 1 (skill catalog generator), already shipped on this branch, so both surfaces are sourced the same way.

## Problem

`using-superpowers/SKILL.md`'s "Skill Priority" section gives only 2 worked routing examples ("Let's build X" → brainstorming, "Fix this bug" → systematic-debugging) against a 16-skill library. For every trigger phrase outside those two, the agent is enforcing an absolute mandate ("YOU DO NOT HAVE A CHOICE") with no routing guidance, which risks wrong-skill selection or invocation thrashing — the exact failure mode idea 5 was written to close.

Every skill's `description` frontmatter already states its own trigger condition, almost always as a literal "Use when ..." clause (15 of 16 skills; `brainstorming` is the one exception — its description opens with "You MUST use this before any creative work" instead). This is the same source-of-truth idea 1 already draws from for the README catalog.

## Non-goals

- No shared library file (`scripts/lib/...`) to de-duplicate frontmatter-extraction code between this script and `generate-skill-catalog.sh`. The repo has no existing lib convention (each of the two current scripts, `generate-skill-catalog.sh` and `lint-shell.sh`, is self-contained); introducing one is a separately-scoped refactor, not part of this low-complexity project. The ~15 lines of extraction logic are duplicated instead.
- No change to `generate-skill-catalog.sh` or `README.md`. This is a new, independent script and a new marker block in a different file.
- No CI wiring, matching the precedent already set by the catalog-generator and CONTRIBUTING.md projects.
- `using-superpowers` does not route to itself — it is excluded from its own generated list (15 entries, not 16).
- The two existing hand-written examples ("Let's build X" / "Fix this bug") are left in place as illustrative prose explaining the process-skills-first rule; the generated block is additive, listed separately as the exhaustive reference.

## Design

### 1. Trigger-clause extraction

For each skill's `description` (excluding `using-superpowers`):

1. Strip the literal leading `Use when ` prefix if present.
2. Truncate at the first ` — ` (em dash) or ` - ` (hyphen with surrounding spaces) — both are used inconsistently across existing descriptions as the separator between the trigger clause and the mechanism/rationale clause that follows. Descriptions with no such separator are used in full.
3. `brainstorming` has no `Use when` prefix; step 1 is a no-op for it and step 2 still applies, yielding "You MUST use this before any creative work".

Verified against all 16 descriptions by hand; every one produces a clean, grammatical clause (see design-review scratch work — no script output has a dangling clause or truncated mid-word).

### 2. Generator script: `scripts/generate-routing-table.sh`

Same shape as `generate-skill-catalog.sh` (`[--check] [target-file]`, default target `skills/using-superpowers/SKILL.md`, marker-delimited replacement, `--check` diffs without writing). New markers, scoped to this file only:

```
<!-- BEGIN GENERATED ROUTING TABLE -->
<!-- END GENERATED ROUTING TABLE -->
```

**Output format**, one bullet per non-`using-superpowers` skill, sorted alphabetically by directory name (matching the catalog script's sort order):

```
- Use when {clause} → superpowers:{name}
```

For `brainstorming`, since its clause doesn't restate "Use when", the literal prefix is omitted for that one line only:

```
- {clause} → superpowers:{name}
```

(i.e. `- You MUST use this before any creative work → superpowers:brainstorming`)

### 3. `skills/using-superpowers/SKILL.md` restructure

Add a new subsection directly under the existing "Skill Priority" prose and its two hand-written examples:

```markdown
## Skill Priority

When multiple skills apply, process skills come first — they set the approach, then implementation skills (frontend-design, etc.) carry it out. Brainstorming and systematic-debugging are Superpowers' most common process skills, but the rule holds for any of them.

- "Let's build X" → superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

### Full Routing Reference

<!-- BEGIN GENERATED ROUTING TABLE -->
<!-- END GENERATED ROUTING TABLE -->
```

Nothing else in the file changes.

## Testing / Verification

New test file `tests/skill-catalog/test-generate-routing-table.sh`, mirroring the existing catalog test file's helper/pattern (`make_target_file`, `pass`/`fail`, mktemp fixtures) plus the real-file regression test added in the prior finding fix:

- Extraction produces 15 bullets (16 skills minus `using-superpowers`), alphabetically sorted.
- `brainstorming`'s line omits the `Use when` prefix; every other line includes it.
- A description containing " - " and one containing " — " both truncate correctly (regression coverage for the two separator styles).
- `--check` exits 0 when in sync, exits 1 with a diff when stale, and never writes in check mode.
- Default mode preserves content outside the markers.
- Missing-markers error path.
- `--check` (no target arg) passes against the real `skills/using-superpowers/SKILL.md` once generated — same real-file regression pattern just added for the catalog script.

## Out of scope for this project (tracked separately)

- Idea 2: Consolidated troubleshooting/FAQ doc (Medium complexity)
- Idea 6: Bootstrap CONCEPTS.md (Low complexity, separate project)
- Idea 7: Baseline-test discipline — explicitly excluded by user request
