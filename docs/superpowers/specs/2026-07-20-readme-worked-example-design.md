# Design: README Worked Example

**Date:** 2026-07-20
**Source:** Survivor idea 4 of [docs/ideation/2026-07-19-onboarding-docs-ideation.md](../../ideation/2026-07-19-onboarding-docs-ideation.md)
**Scope:** README.md only. Second of six onboarding-docs projects, sequenced low-complexity-first (follows [2026-07-20-contributing-guide-design.md](2026-07-20-contributing-guide-design.md)).

## Problem

`README.md`'s value-prop sentence — "you don't need to do anything special... your coding agent just has Superpowers" (line ~15) — is currently unfalsifiable to a first-time reader. The file's only code blocks are bare `/plugin install` commands (lines ~21-30); there is no usage transcript or worked example anywhere in its ~90 lines. A reader has no evidence for the claim before hitting the 7-step "Basic Workflow" list, which is the file's first structured content.

Separately, the two install paths (official marketplace vs. `obra/superpowers-marketplace`) are presented with no indication of whether they differ, leaving a reader to guess.

## Non-goals

- No changes to "How it works," "The Basic Workflow," "What's Inside," "Philosophy," "License," or the telemetry note. These sections are unchanged, only shifted down by the new section.
- No multi-stage transcript (brainstorming → plan → implementation). The example is a single trigger moment, matching the "readable in under 30 seconds" convention this idea is grounded in.
- No new marketplace tooling or functional differentiation logic — the two marketplaces install the identical plugin; the fix is a one-sentence clarification, not a decision tree.

## Design

### 1. New "See it in action" section

Insert a new `## See it in action` section immediately after `## Installation` and before `## The Basic Workflow`. Content:

```markdown
## See it in action

> "Let's build a rate limiter for the API"

Agent: *Using brainstorming to explore the rate limiter design...*

[asks clarifying questions, proposes approaches, presents a
design for approval — before any code gets written]
```

This is a single trigger→response moment: one user prompt, the agent's immediate skill-invocation announcement, and one bracketed line summarizing what follows. It directly backs the "you don't need to do anything special" claim in "How it works" with concrete proof, positioned right after a reader has just installed the plugin — the point where "does this actually work?" is most live.

### 2. Marketplace clarification

In the `## Installation` section, add one sentence between the two `/plugin install` blocks clarifying that both marketplaces install the identical plugin and there is no functional difference — e.g. "Both marketplaces install the identical plugin; pick whichever you already have configured." This replaces the current undifferentiated presentation of the two options with an explicit statement that the choice doesn't matter.

## Testing / Verification

Documentation-only change; verification is a read-through, not automated tests:

- Read the full modified README.md end-to-end to confirm section order flows naturally: pitch → how it works → installation (with clarified marketplace choice) → worked example → basic workflow → skill catalog → philosophy → license → telemetry.
- Confirm the new section's markdown renders correctly (blockquote, italics, bracketed summary line).
- Confirm no existing section's wording was altered beyond the one added marketplace sentence.

## Out of scope for this project (tracked separately)

- Idea 1: Auto-generate the skill catalog from frontmatter (Medium complexity)
- Idea 2: Consolidated troubleshooting/FAQ doc (Medium complexity)
- Idea 3: CONTRIBUTING.md + description-skip bug fix (Low complexity — separate project, already speced)
- Idea 5: Expand Skill Priority routing table (Low complexity, separate project)
- Idea 6: Bootstrap CONCEPTS.md (Low complexity, separate project)
- Idea 7: Baseline-test discipline for onboarding docs — explicitly excluded by user request
