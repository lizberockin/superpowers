# Design: CONTRIBUTING.md + Description-Skip Warning Placement

**Date:** 2026-07-20
**Source:** Survivor idea 3 of [docs/ideation/2026-07-19-onboarding-docs-ideation.md](../ideation/2026-07-19-onboarding-docs-ideation.md)
**Scope:** Docs-only (no lint check, no CI) — first of six low/medium-complexity onboarding-docs projects, sequenced low-complexity-first.

## Problem

Two separate gaps in contributor onboarding:

1. No `CONTRIBUTING.md` exists at repo root. `skills/writing-skills/SKILL.md` is the closest thing to a contributor guide (a 691-line TDD-for-skills methodology) but is only discoverable by browsing the README's skill catalog — nothing signposts it as "start here to contribute."
2. A real, reproduced defect — a skill `description` that summarizes the skill's workflow causes an agent to follow the description instead of reading the skill body, skipping steps — is documented in full at `skills/writing-skills/SKILL.md:142-199` (the "Skill Discovery Optimization" section), but the frontmatter-writing guidance at `SKILL.md:95-105`, where a contributor is actually about to write a `description` field, only has a one-line forward pointer ("see SDO section for why"). A contributor can miss it.

## Non-goals

- No mechanical lint check or CI validation of skill frontmatter. The repo has no CI pipeline today (no `.github/workflows`); building one is a separately-scoped investment, not part of this low-complexity project.
- No invented PR checklist, branch-naming convention, or testing-process documentation in `CONTRIBUTING.md`. None of that exists elsewhere in the repo; inventing it here would be unenforced fiction rather than reflecting real practice.
- No restructuring of `writing-skills/SKILL.md`'s existing section order. The SDO section (lines 142-199) stays exactly where it is, unchanged.

## Design

### 1. New `CONTRIBUTING.md` at repo root

Minimal, pointer-style document:

- One short paragraph: what this repo is (a library of markdown-defined agent skills) and that skills are the primary contribution surface.
- **"Adding or editing a skill"** section: points to `skills/writing-skills/SKILL.md` as the required starting point, names the TDD-for-skills methodology it enforces (baseline scenario before writing, pressure-test with subagents, etc.) in one sentence so the pointer carries context, not just a bare link.
- **"Reporting issues"** section: one line, pointing to GitHub issues.

No other sections. Length target: well under 50 lines.

### 2. Condensed warning in `skills/writing-skills/SKILL.md`

Insert a blockquote callout immediately after the existing `description` bullet in the "SKILL.md Structure" section (currently ending around line 105), before the code-block template that follows:

```markdown
- `description`: Third-person, describes ONLY when to use (NOT what it does)
  - Start with "Use when..." to focus on triggering conditions
  - Include specific symptoms, situations, and contexts
  - **NEVER summarize the skill's process or workflow** (see SDO section for why)
  - Keep under 500 characters if possible

> ⚠️ **Before you write this field:** a description that summarizes the
> skill's workflow will cause agents to follow the description instead of
> reading the skill — this has been reproduced. See "Skill Discovery
> Optimization" below for the full explanation and examples.
```

The full explanation, rationale, and bad/good example pairs already at lines 142-199 (the SDO section) are left completely unchanged — this is additive, not a rewrite. Line numbers after this section will shift down slightly; nothing in the repo currently cites exact line numbers into this file except the ideation doc, which is a historical record and is not expected to stay pinned to exact lines.

## Testing / Verification

This is a documentation-only change with no executable behavior, so verification is a read-through, not automated tests:

- Read `CONTRIBUTING.md` end-to-end for tone, accuracy, and that it doesn't contradict `writing-skills/SKILL.md`.
- Read the modified section of `writing-skills/SKILL.md` end-to-end to confirm the new callout doesn't duplicate the SDO section awkwardly and reads naturally in context.
- Confirm no other file in the repo depends on `writing-skills/SKILL.md`'s current line numbers or exact section boundaries in a way this change would break.

## Out of scope for this project (tracked separately)

- Idea 1: Auto-generate the skill catalog from frontmatter (Medium complexity)
- Idea 2: Consolidated troubleshooting/FAQ doc (Medium complexity)
- Idea 4: README worked example (Low complexity, separate project)
- Idea 5: Expand Skill Priority routing table (Low complexity, separate project)
- Idea 6: Bootstrap CONCEPTS.md (Low complexity, separate project)
- Idea 7: Baseline-test discipline for onboarding docs — explicitly excluded by user request
