# Ideation: Improving the Onboarding Docs

How a new human evaluator, and the coding agent itself, learn to use the Superpowers skills system — and where that experience currently loses people.

**Date:** 2026-07-19 · **Topic:** onboarding-docs · **Focus:** improving the onboarding docs in this repo · **Mode:** repo-grounded

**Stats:** 45 raw ideas generated · 18 merged candidates · 7 survivors · 5/5 axes covered

## Codebase Context

Superpowers is an open-source Claude Code plugin distributing a library of markdown-defined agent "skills" (each a `SKILL.md` plus optional `references/`), installed via `/plugin install`. Onboarding today has two entry points with different audiences and no shared source of truth between them:

- **`README.md`** — value prop, two install paths (official marketplace vs. `obra/superpowers-marketplace`, undifferentiated), a 7-step "Basic Workflow" list, a hand-maintained "What's Inside" skill catalog, philosophy, license. No worked example anywhere in the file.
- **`skills/using-superpowers/SKILL.md`** — the agent-facing entry point. Opens directly with an `<EXTREMELY-IMPORTANT>` mandate block ("not negotiable"), a "Skill Priority" routing table covering only 2 of the repo's 16 skills, and a "Red Flags" rationalization table. Written for the agent, with no framing for a human reader.
- **`skills/writing-skills/`** — the closest thing to a contributor guide (a 691-line TDD-for-skills methodology). Listed in the README's Meta category but not signposted anywhere as "start here to contribute."
- No `AGENTS.md`, `CLAUDE.md`, `CONTRIBUTING.md`, `STRATEGY.md`, or `CONCEPTS.md` at repo root. No `docs/solutions/` learnings corpus exists yet — this repo has never applied its own `compound-learnings` skill to itself.

External research (moderate confidence — see basis citations below) confirms the README-as-evaluation-funnel convention (a working example before any step list), the AGENTS.md/llms.txt convention for agent-facing instructions kept separate from human docs, and names exhaustive troubleshooting/error documentation as the single highest-leverage content type for AI-agent-consumed docs — a content type this repo currently has none of.

## Topic Axes

1. **Human entry / README** — The install-to-first-value funnel a human evaluator hits first.
2. **Agent-facing entry-point instructions** — How the coding agent itself is onboarded — `using-superpowers`, routing language.
3. **Skill-library discoverability** — Finding "which skill do I need" among 16 skills; workflow-sequence visibility.
4. **Contributor onboarding** — Learning to write or modify a skill; implicit vs. explicit conventions.
5. **Troubleshooting / FAQ** — What happens when a step is skipped, a workflow deviates, or a common question arises.

## Ranked Ideas

1. [Auto-generate the skill catalog from frontmatter](#1-auto-generate-the-skill-catalog-from-frontmatter)
2. [Consolidated troubleshooting / FAQ doc](#2-consolidated-troubleshooting--faq-doc)
3. [CONTRIBUTING.md + fix the description-skip bug at its source](#3-contributingmd--fix-the-description-skip-bug-at-its-source)
4. [Lead the README with a worked example, not a step list](#4-lead-the-readme-with-a-worked-example-not-a-step-list)
5. [Expand the Skill Priority routing table to full coverage](#5-expand-the-skill-priority-routing-table-to-full-coverage)
6. [Bootstrap CONCEPTS.md by pointing compound-learnings at this repo's own onboarding](#6-bootstrap-conceptsmd-by-pointing-compound-learnings-at-this-repos-own-onboarding)
7. [Apply the repo's own baseline-test discipline to onboarding docs](#7-apply-the-repos-own-baseline-test-discipline-to-onboarding-docs)

---

### 1. Auto-generate the skill catalog from frontmatter

**Axis:** Skill-library discoverability · **Confidence:** 85% · **Complexity:** Medium

**Description:** Replace the README's hand-maintained "What's Inside" skill catalog with one generated from each skill's own frontmatter (`name` + `description`), regenerated on every skill addition, with a CI check that fails the build if the checked-in section drifts from the generated output.

**Basis:**
- *direct:* Verified by direct comparison: `ls skills/` returns 16 directories, but README.md's "What's Inside" catalog lists only 14 — `compound-learnings` and `ideate` are both missing entirely. This is a live, present-tense bug, not a hypothetical risk. Independently proposed by 6 of the 45 raw ideas across 4 different frames.

**Rationale:** The catalog's entire job is making skills discoverable, and it is currently failing at that job for two shipped skills. A generated source of truth doesn't just fix today's gap — it removes an entire class of future onboarding bugs (stale or missing entries) every time a skill is added, for zero ongoing contributor discipline.

**Downsides:** Requires a small generator script plus a CI wiring decision (fail-the-build vs. warn); someone has to own the generator's category-grouping logic (Testing / Debugging / Collaboration / Meta) since frontmatter doesn't currently carry a category field.

**Today:** 16 skills' frontmatter → *(hand-copy)* → README catalog (14 of 16 listed)
**Proposed:** 16 skills' frontmatter → *(generate)* → README catalog (16 of 16, always) → CI check blocks drift

---

### 2. Consolidated troubleshooting / FAQ doc

**Axis:** Troubleshooting / FAQ · **Confidence:** 88% · **Complexity:** Medium

**Description:** Create a single `TROUBLESHOOTING.md` (or equivalent) aggregating the "Red Flags" and anti-pattern content currently scattered across individual skills, seeded with known concrete failure modes: the description-summary skip bug, session-memory loss across compaction, silent cost escalation from omitted model selection, and context pollution from pasted history. Link to it from README and `using-superpowers` rather than duplicating content per skill.

**Basis:**
- *direct:* The Red Flags table in `using-superpowers/SKILL.md` (lines 33-51) is verified to exist with 12 rationalization/reality pairs (e.g. "This is just a simple question" → "Questions are tasks. Check for skills."). A repo-wide grep found this pattern is more scattered than any single generating agent claimed — 11 of 16 skill files contain Red-Flag/anti-pattern content, with no standalone troubleshooting surface anywhere.
- *external:* exhaustive troubleshooting/error documentation is independently cited as the single highest-leverage content type for AI-agent-consumed docs (Cloudflare's docs-for-agents guidance). This is the strongest convergence cluster in the whole ideation set — 6 of the 45 raw ideas, across all 5 frames, proposed some version of it.

**Rationale:** A user or agent hitting a wall today has no single place to look — they have to already know which specific skill file might contain the relevant table. External research names this exact content type as the top lever for this exact audience, yet the repo currently ships zero of it.

**Downsides:** Risk of the new doc drifting from the per-skill tables it's meant to summarize unless it transcludes or is generated rather than hand-copied. Directly conflicts with a rejected alternative (distribute warnings just-in-time instead of centralizing) — see the Rejection Summary; the team should treat that as a real open question, not a settled one.

**Today:** scattered across 11 of 16 skill files (using-superpowers, TDD, sys-debugging, git-worktrees, +7 more)
**Proposed:** `TROUBLESHOOTING.md` — one linked surface

---

### 3. CONTRIBUTING.md + fix the description-skip bug at its source

**Axis:** Contributor onboarding · **Confidence:** 82% · **Complexity:** Low

**Description:** Add a top-level `CONTRIBUTING.md` that points newcomers to `skills/writing-skills/` as "start here." While there, elevate the documented description-skip pitfall from a paragraph deep in a 691-line file into an explicit, hard-to-miss warning (or a mechanical pre-merge check) in the frontmatter-writing guidance itself.

**Basis:**
- *direct:* Verified near-verbatim at `skills/writing-skills/SKILL.md:156`: "Testing revealed that when a description summarizes the skill's workflow, an agent may follow the description instead of reading the full skill content. A description saying 'code review between tasks' caused an agent to do ONE review, even though the skill's flowchart clearly showed TWO reviews." This is a real, reproduced defect, not a hypothetical. `writing-skills` is listed in README's Meta category but is not otherwise signposted as a contributor entry point — no `CONTRIBUTING.md` exists at repo root.

**Rationale:** This is a landmine that will silently recur in every future skill a contributor writes until it's written down somewhere they'll actually see it before hitting it. A one-time signpost plus an explicit warning is cheap and closes an entire class of future bug reports.

**Downsides:** A mechanical lint check (vs. just a stronger warning) is a larger, separately-scoped investment; the two halves of this idea (signposting vs. bug-proofing) could ship independently if the team wants to phase it.

---

### 4. Lead the README with a worked example, not a step list

**Axis:** Human entry / README · **Confidence:** 80% · **Complexity:** Low

**Description:** Restructure README.md so a concrete before/after transcript ("you say 'let's build X' → the agent announces 'Using brainstorming to...'") appears immediately after the one-line pitch, before the 7-step "Basic Workflow" list and the skill catalog. The existing content doesn't change, only its position relative to proof. Bundle in a one-sentence fix for the undifferentiated two-marketplace install choice while touching this section.

**Basis:**
- *direct:* Confirmed by full read: README.md's only code blocks (lines ~21-30) are bare `/plugin install` commands — there is no usage transcript or worked example anywhere in its ~90 lines. The value-prop sentence "you don't need to do anything special" (line ~15) is currently unfalsifiable to a new reader.
- *external:* 2026 README-as-onboarding-funnel guidance converges on a working example achievable in under 30 seconds appearing before any multi-step list. Independently proposed by 5 of the 6 ideation frames.

**Rationale:** The README is the entire evaluation funnel for a first-time visitor deciding whether to install. Every other onboarding surface only gets read after someone already decided to try it, so this is the single highest-leverage rewrite for top-of-funnel conversion.

**Downsides:** Requires picking one canonical worked example to feature, which is an editorial choice worth a quick team sign-off; a stale or unrepresentative example would undermine trust rather than build it.

**Before:** Narrative value-prop prose → 7-step workflow list (first structured content) → Skill catalog
**After:** One-line pitch → Worked example transcript (new, <30s) → 7-step workflow list, now supporting detail

---

### 5. Expand the Skill Priority routing table to full coverage

**Axis:** Agent-facing entry-point instructions · **Confidence:** 78% · **Complexity:** Low

**Description:** Expand `using-superpowers/SKILL.md`'s "Skill Priority" section from its current two worked examples into coverage of the repo's full skill inventory — either hand-written or, better, generated from each skill's own "Use when..." description (the convention already exists in every skill's frontmatter).

**Basis:**
- *direct:* Verified exactly: `using-superpowers/SKILL.md` lines 26-31 give only 2 worked routing examples ("Let's build X" → brainstorming, "Fix this bug" → systematic-debugging), confirmed against `ls skills/` showing 16 skills total — 14 have no stated routing rule at all.

**Rationale:** The file's own mandate is absolute — "YOU DO NOT HAVE A CHOICE" — but the routing table backing that mandate covers a fraction of the library. For every other trigger phrase, the agent is enforcing a hard rule with no guidance on which skill applies, which produces either wrong-skill selection or invocation thrashing. This is the mechanism that makes the whole system's "mandatory" claim actually work.

**Downsides:** A generated version (sourced from descriptions) is more durable but is a build-process decision, not just a content edit; a hand-written expansion is faster to ship but reintroduces the same drift risk this ideation flagged elsewhere (see idea 1).

**Routing table coverage:** Today 2/16 skills → Proposed 16/16 skills

---

### 6. Bootstrap CONCEPTS.md by pointing compound-learnings at this repo's own onboarding

**Axis:** Agent-facing entry-point instructions · **Confidence:** 68% · **Complexity:** Low

**Description:** The repo ships a `compound-learnings` skill whose stated job is capturing durable conventions in `docs/solutions/` or `CONCEPTS.md` "before context is lost" — but this repo has never applied that skill to itself. Bootstrap a `CONCEPTS.md` seeded with the landmines already surfaced in this exact ideation run: the description-skip bug, the mandatory-invocation rationale, the two-marketplace relationship — so the next round of onboarding-doc work starts from a real corpus instead of "none found."

**Basis:**
- *direct:* `skills/compound-learnings/SKILL.md` exists with a description matching this claim near-verbatim: "captures it as searchable documentation in `docs/solutions/` or `CONCEPTS.md` before the context is lost." Verified directly that no `CONCEPTS.md` and no `docs/solutions/` exist anywhere in this repo.

**Rationale:** Every other idea in this set produces a fact worth remembering (a bug, a convention, a rationale), and the repo currently has no mechanism actually recording those facts for itself despite owning a skill built for exactly that purpose. This is the meta-compounding move — it makes every future iteration of this exact ideation exercise start from evidence instead of from scratch.

**Downsides:** Lower urgency than the doc-facing survivors above; value is entirely in future leverage, not in fixing anything a user hits today. Worth a real "do we want to eat our own dog food here" discussion rather than a drive-by edit.

---

### 7. Apply the repo's own baseline-test discipline to onboarding docs

**Axis:** Agent-facing entry-point instructions · **Confidence:** 62% · **Complexity:** High

**Description:** The repo's own `writing-skills` methodology mandates running a baseline scenario before writing any individual skill — watch a naive agent fail, then write minimal content to close the gap. That discipline has never been applied reflexively to the onboarding docs as a whole system. Build a small suite of canonical prompts ("let's build X," "fix this bug," "I want to add a new skill") run against a fresh agent seeded only with README + `using-superpowers/SKILL.md`, scoring whether it reaches the intended path — turning "does onboarding work" from a belief into a regression-testable claim.

**Basis:**
- *direct:* Verified verbatim at `writing-skills/SKILL.md:39`: "Write test first → Run baseline scenario BEFORE writing skill," reinforced by line 16: "If you didn't watch an agent fail without the skill, you don't know if the skill teaches the right thing." No equivalent suite exists for onboarding docs as a system today.

**Rationale:** Every other idea in this set improves onboarding by inspection and judgment; this one gives the team a mechanical way to know whether any of those changes actually worked, and prevents regressions as the skill count grows past 16.

**Downsides:** Real build cost — this is a tooling investment, not a doc edit, and its value depends on the other survivors landing first (there's little to regression-test against yet). Scope and ownership are worth a dedicated discussion before committing.

---

## Open Strategic Tensions (not resolved by this ideation)

- **Centralize vs. distribute troubleshooting content.** Idea 2 proposes one consolidated troubleshooting doc; a rejected alternative (M13) argued for pushing warnings out to the point of failure inside each skill instead. Both rest on the same evidence; they pull in opposite directions.
- **Enrich vs. strip the README / using-superpowers pair.** Idea 4 pushes toward a richer README; two rejected alternatives (M10, M18) argued for the opposite — stripping mechanics out of the README entirely and pushing everything into the skill file. These are mutually exclusive directions for the same two files.

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|------------------|
| M2 | Marketplace-choice decision line | Folded into survivor 4's README pass as a one-sentence addition — not distinct enough for its own slot. |
| M6 | Skill decision-tree / dependency graph | Duplicates a stronger idea — overlaps survivor 1 on the same axis; survivor 1 has the stronger, present-tense-bug-backed basis. |
| M10 | Human-facing rationale layer for the mandate system | Below the cut; also in direct tension with M18 on the same two files — a strategic fork the team should resolve explicitly. |
| M12 | Interactive "getting-started" skill | Verifier: "partly reasoned not evidenced" — weaker basis than the top 7; speculative in scope and cost. |
| M13 | Just-in-time contextual warnings at point of failure | Conflicting alternative to survivor 2 (centralize vs. distribute); survivor 2 has stronger convergence and external validation. Noted as an open tension, not silently dropped. |
| M14 | "Is this for you? / Not for you if..." section | Sound and verified, but lower urgency than the top 7; more a positioning/brainstorming question than an ideation-level pick. |
| M15 | Stress-test using-superpowers' own description field | Basis refuted-as-weak by verification: "borderline case, not a clean match to the documented bug pattern; severity is asserted, not demonstrated." |
| M16 | Self-service scaffolding generator (create-skill) | Verifier: the leap from "long doc" to "build a scaffolding tool" is reasonable but not the only fix; overlaps survivor 3's axis with a cheaper alternative already ahead of it. |
| M17 | Repurpose Red Flags table as a human-facing FAQ | Duplicates a stronger idea — subsumed by survivor 2, which is a superset of this move. |
| M18 | Fork README / using-superpowers further apart | Conflicting alternative to survivor 4; directly contradicts the enrich-with-worked-example direction, which has stronger convergence and verified evidence. |
| — | Self-diagnosis block for silent degradation (context pollution, memory loss, cost escalation) | Folded into survivor 2's seed list of failure modes rather than standing alone. |

---

*Composed 2026-07-19 by ideate from grounding gathered via codebase scan, institutional-learnings search, web research, and 5 axis-scoped evidence dossiers (repo: superpowers, run c626243d).*
