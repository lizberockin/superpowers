# Integrating gstack and compound-engineering skills into Superpowers

## Goal

An easily-installed, core skill set for Claude Code to use across every project — install once via the plugin mechanism, no per-project setup, no external daemon or CLI dependency. The five incoming skills shouldn't just sit alongside the existing library as five more independent commands: the point is an *integrated* system where skills hand off to and reinforce each other, and where the system gets more useful the more it's used — `office-hours` feeds into `brainstorming` feeds into `writing-plans`; `compound-learnings` captures what gets solved, and other skills consult it on later runs. This is the lens the rest of this spec is written through: prefer wiring skills together (cross-links, a shared wiki, deliberate sequencing) over shipping them as isolated bolt-ons.

## Problem

Three sibling repos in `~/AI` each carry valuable, non-overlapping skill content:

- **superpowers** — the target. This fork is a personal, Claude-Code-only skills library (multi-harness support for Codex/Cursor/Kimi/OpenCode/Pi/Gemini, along with the upstream project's release notes and contribution machinery, was stripped in a prior cleanup pass) with a flat skill namespace, a minimal two-field frontmatter contract (`name`, `description`), no runtime dependencies beyond Claude Code itself, and a strict authoring discipline (`writing-skills`) built on TDD-for-docs.
- **gstack** — has three skills we want: `office-hours` (YC-style idea-validation forcing questions + builder-mode design brainstorming), `plan-ceo-review` (scope/ambition review of a plan), `plan-eng-review` (engineering-rigor review of a plan). These are excellent *content*, but they are deeply wired into gstack's private runtime.
- **compound-engineering** — has two skills we want: `ce-compound` (capture a solved problem as durable docs, with overlap detection and cross-referencing) and `ce-ideate` (generate and evaluate grounded ideas via parallel research subagents). These are much closer to superpowers' own conventions already.

The naive move — copying directories across — will not work cleanly, because "what makes these skills powerful in their respective repos" is partly content (the methodology, the review rubrics, the forcing questions) and partly *infrastructure* (gstack's `~/.gstack` global brain, its `bin/gstack-*` CLI, its template build pipeline; compound-engineering's local `references/agents/*` subagent-dispatch pattern). Some of that infrastructure travels well. Some of it doesn't exist in superpowers and re-implementing it would be scope creep. This spec inventories both, and defines what to port, what to translate, and what to intentionally drop.

## Source inventory

### gstack skills (`office-hours`, `plan-ceo-review`, `plan-eng-review`)

Each skill directory has the shape:
```
<skill>/
  SKILL.md            # checked-in, generated output — this is what ships
  SKILL.md.tmpl        # source of truth, rendered via `bun run gen:skill-docs`
  sections/
    manifest.json       # passive index: {id, file, title, trigger} — no logic
    <name>.md            # progressive-disclosure content, read on demand
    <name>.md.tmpl
```

Frontmatter fields beyond `name`/`description`: `preamble-tier`, `version`, `interactive`, `benefits-from` (cross-skill chaining — e.g. `plan-ceo-review` and `plan-eng-review` both declare `benefits-from: [office-hours]`), `allowed-tools`, `triggers` (proactive-invocation keyword list), and a `gbrain` block of `context_queries` that pull from gstack's global memory store (`~/.gstack/projects/{repo_slug}/...`, `~/.gstack/analytics/eureka.jsonl`, a `gbrain` list/filesystem query engine keyed on repo slug).

Every one of these SKILL.md files opens with a **Preamble (run first)** bash block that shells out to `~/.claude/skills/gstack/bin/gstack-update-check`, `gstack-config`, `gstack-repo-mode`, `gstack-session-kind`, writes session heartbeat files under `~/.gstack/sessions/`, and echoes `BRANCH`/`PROACTIVE`/`REPO_MODE`/`SESSION_KIND` variables that the rest of the skill body branches on (e.g. `plan-eng-review` explicitly branches "spawned / headless / interactive" on `SESSION_KIND`).

**What's portable:**
- The `sections/manifest.json` + on-demand-read pattern is just progressive disclosure — the same idea `writing-skills` already recommends ("Read them on-demand at the step that needs them"). No gstack runtime involved. Keep it, minus the `.tmpl` layer.
- The actual review rubrics, forcing-question sets, and section content are pure markdown methodology. Fully portable.
- `benefits-from` is a useful *concept* (soft skill-chaining hint) even though superpowers has no field for it today.

**What's not portable (gstack-proprietary runtime):**
- `bin/gstack-update-check`, `gstack-config`, `gstack-repo-mode`, `gstack-session-kind` — these binaries don't exist outside gstack's install. Calling them in superpowers would silently no-op via `|| true`/`|| echo fallback` guards already in the script, but they're dead weight and confusing to a reader trying to understand the skill.
- The `gbrain` context-query block — depends on a global `~/.gstack/` memory daemon and repo-slug indexing that superpowers doesn't have and shouldn't grow just for these three skills.
- `SKILL.md.tmpl` + `bun run gen:skill-docs` — a gstack-repo-wide codegen pipeline (templates render into checked-in files). superpowers has no equivalent build step and skills are hand-authored. The rendered `SKILL.md` is the thing to port; the `.tmpl` is not.
- `preamble-tier`, `interactive`, `allowed-tools`, `triggers`, `gbrain` frontmatter keys — these are gstack's skill-loader contract, not Claude Code's. They're harmless extra YAML if left in, but they imply behavior (proactive triggers, tool allowlisting) that nothing on the superpowers side enforces, so leaving them in is misleading.

### compound-engineering skills (`ce-compound`, `ce-ideate`)

Shape:
```
ce-<skill>/
  SKILL.md                     # name, description, argument-hint only
  references/
    *.md                        # schemas, vocab, workflow docs — read on demand
    agents/*.md                  # subagent prompts, dispatched as generic subagents
  scripts/*.py, *.sh             # validation / extraction helpers, invoked via Bash
  assets/*.md                    # output templates
```

Frontmatter is already minimal (`name`, `description`, `argument-hint` — the last is a slash-command convention, not a Skill one). Subagent work is dispatched with the **generic-subagent-plus-local-prompt-file** pattern: *"read `references/agents/web-researcher.md` and seed a generic subagent with that prompt"* — no custom named agent types, no registration anywhere else in the repo. This is exactly the pattern superpowers itself uses (see `skills/subagent-driven-development/implementer-prompt.md`, `skills/requesting-code-review/code-reviewer.md`). It ports with zero translation.

The `scripts/*.py` helpers (YAML/frontmatter validation, session-history extraction) are self-contained (stdlib-only where checked) and travel with their skill directory unchanged.

**Naming note:** `ce-` is a namespace prefix compound-engineering uses because it ships many skills (`ce-brainstorm`, `ce-plan`, `ce-debug`, ...) that would otherwise collide with common words. superpowers doesn't namespace (flat, e.g. `brainstorming`, `writing-plans`) because it curates a small set and avoids collisions deliberately. Bringing `ce-compound`/`ce-ideate` in verbatim would be the only prefixed names in the library and would read as orphaned. Recommend dropping the prefix and renaming to fit superpowers' gerund/descriptive convention.

## Overlap with existing superpowers skills

Before wiring anything in, note where the incoming skills sit relative to what's already there, so the merge reads as one coherent library instead of two workflows bolted together:

| Incoming | Existing superpowers skill | Relationship |
|---|---|---|
| `office-hours` | `brainstorming` | Different altitude: `brainstorming` turns an idea into an approved design for something you're already building; `office-hours` decides *whether the idea is worth building at all* (YC forcing questions) and, in builder mode, does open-ended design brainstorming. Sequence: `office-hours` → `brainstorming` → `writing-plans`, not a replacement. |
| `plan-ceo-review` | `writing-plans`, `brainstorming` | Reviews a plan's *ambition/scope* after a plan exists. Complements `writing-plans`; doesn't overlap it. |
| `plan-eng-review` | `requesting-code-review`, `writing-plans` | Reviews a *plan's* engineering rigor before execution, where `requesting-code-review` reviews *code* after implementation. Different lifecycle stage — keep both. |
| `ce-compound` | none directly — closest is `writing-skills`' "create when you'd reference this again" ethos | Fills a real gap: superpowers has no "capture a learning as durable docs right after solving it" skill. Clean addition. |
| `ce-ideate` | `brainstorming` | `brainstorming` is dialogue-driven (ask user one question at a time). `ce-ideate` is subagent-research-driven (dispatches web/learnings/issue-tracker research to generate options before a human picks one). Complementary entry points into the same funnel, not duplicates — cross-link them. |

## Wiki consultation points across superpowers

`ce-compound`'s `docs/solutions/` + `CONCEPTS.md` isn't just a substitute for `gbrain` inside the three ported skills — it's a general capability superpowers doesn't currently have (a git-tracked, schema-validated record of previously solved problems and durable vocabulary). Once `compound-learnings` exists, several *existing* superpowers skills should consult it too, not just the newly-ported ones:

| Skill | Where the wiki fits | Why it's worth the addition |
|---|---|---|
| `systematic-debugging` | Add a step, before root-cause analysis begins, to search `docs/solutions/` for a matching previously-solved problem. | This is the single highest-value hookup — `docs/solutions/` exists specifically to capture solved problems, and re-solving a bug that was already root-caused and documented is exactly the waste `compound-learnings` is designed to prevent. |
| `writing-plans` | When establishing a plan's "Context" section, check `CONCEPTS.md` for established vocabulary/architecture terms and `docs/solutions/` for prior related decisions, before writing new context from scratch. | Keeps plans consistent with terminology and decisions the team already settled, instead of re-deriving or (worse) silently contradicting them. |
| `brainstorming` | Fold wiki search into the existing "Explore project context" checklist step, alongside files/docs/commits. | Same rationale as `writing-plans`, earlier in the lifecycle — surfaces relevant prior art before proposing approaches. |
| `finishing-a-development-branch` | Add a closing prompt: "was there a learning here worth capturing? consider `compound-learnings`." | This is a **write-side** hookup, not a read one — branch-finish is the natural "context is fresh" moment `ce-compound`'s own docs call out as the right time to document a solved problem. Without a prompt at this specific point, the wiki never gets populated. |
| `requesting-code-review` / `receiving-code-review` | Check the wiki for already-documented anti-patterns relevant to the diff before/while reviewing. | Prevents reviewers from re-litigating a pattern the team already settled and documented (parallels how `test-driven-development/testing-anti-patterns.md` already captures settled anti-patterns inline — the wiki generalizes that beyond testing). |
| `writing-skills` | Add an explicit boundary note distinguishing `compound-learnings` (one-off solved-problem writeup, project-scoped) from `writing-skills` (reusable technique, portable across projects) — with a "graduation" path: a `docs/solutions/` entry that keeps recurring across projects is a signal it should become a skill instead. | Without this, the two systems will drift into ambiguous, overlapping use — authors won't know which one a given piece of knowledge belongs in. |

These are cross-cutting edits to skills outside the five being ported, so they land in Phase 3 (below), after `compound-learnings` exists and after the ported skills demonstrate the consultation pattern works in practice.

## Decisions

1. **Vehicle:** a branch on superpowers (`integrate-gstack-compound-skills`, already created off `main`), not a new repo. Superpowers already provides everything "easily installed" needs: a Claude Code plugin manifest (`.claude-plugin/`), the session-start hook that bootstraps skill discovery, and the existing skill library these five need to integrate with. A new repo would have to rebuild all of that for no reason, and would work against the actual goal — one integrated set, not a second parallel library to keep in sync.
2. **Naming — confirmed:** keep `office-hours`, `plan-ceo-review`, `plan-eng-review` as-is (recognizable, no collisions, already read as noun-phrase skill names compatible with superpowers style; no renaming to match `requesting-code-review`/`receiving-code-review` — kept as their own recognizable pair). Rename `ce-compound` → `compound-learnings` and `ce-ideate` → `ideate`.
3. **Frontmatter:** normalize all five to superpowers' two-field contract (`name`, `description`, third-person "Use when..." phrasing per `writing-skills`). Drop `preamble-tier`, `interactive`, `allowed-tools`, `triggers`, `gbrain`, `argument-hint`, `version`. Preserve `benefits-from` as an informal "See also" prose line in the body (superpowers has no such frontmatter field, and inventing one for three skills isn't warranted — a body cross-reference does the same job for a human or agent reading the file).
4. **gstack runtime dependency:** strip the entire "Preamble (run first)" bash block and every `gbrain` context-query. Replace the *intent* (surface relevant prior work before the skill runs) with a **two-tier, portable context step**:
   - **Primary source: the compound-learnings wiki** (`docs/solutions/` + `CONCEPTS.md`, ported in Phase 1 below). It's the closer match to what `gbrain` was actually giving these skills — a curated, project-scoped record of prior decisions and solved problems — and unlike `gbrain` it's git-tracked, so it's team-shared rather than single-user. `plan-ceo-review`'s "prior CEO plans"/"recent reviews" queries and `office-hours`'s "design-doc-history" query map directly onto searching `docs/solutions/` (and `CONCEPTS.md` for established vocabulary) instead of globbing `~/.gstack/projects/{repo_slug}/`.
   - **Fallback source:** `docs/superpowers/specs/`, `docs/superpowers/plans/` (superpowers' own convention, already used by `brainstorming` and `writing-plans`), plus `git log --oneline -20`. Used when a repo hasn't adopted the wiki yet or it's empty.

   This degrades gracefully at every tier (empty results if nothing's there) instead of depending on a daemon that doesn't exist in this repo. Note the dependency this creates: `compound-learnings` must land before (or in the same change as) `office-hours`/`plan-ceo-review`/`plan-eng-review` reference it — see reordered Migration plan below.

   **Not recovered by either tier:** `gbrain`'s `builder-profile.jsonl` (cross-*repo* personalization) and `eureka.jsonl` (a live analytics stream). Both are genuinely gstack-specific — the wiki and specs/plans are per-repo, not per-user-across-repos, and superpowers has no analytics pipeline to source a `eureka`-style feed from. This is a real, acknowledged capability loss, not an oversight.
5. **gstack progressive disclosure:** keep the `sections/<name>.md` + manifest pattern, minus `.tmpl` sources and minus the `$schema` gstack URL. It matches superpowers' existing "reference file read on demand" style (e.g. `skills/writing-skills/anthropic-best-practices.md`).
6. **compound-engineering subagent dispatch:** port `references/agents/*.md` and `references/*.md` verbatim, path-adjusted only. No translation needed — same pattern superpowers already uses.

   **Note — `ideate` needs explicit subagent testing, not just a copy.** Several of `ideate`'s dispatched subagents (`slack-researcher`, `issue-intelligence-analyst`) assume conditional access to MCP tools that compound-engineering's original environment had wired up (Slack, an issue tracker) and that this environment may not. The originals are written to degrade gracefully — e.g. Slack research is opt-in and "never auto-dispatch," only used "when Slack tools are available" — but that guard needs to be exercised, not assumed to still hold after the move: during Phase 1 pressure-testing, run `ideate` in a session with none of these optional tools present and confirm it neither fails nor silently hallucinates results, and separately confirm the `web-researcher` subagent's WebSearch/WebFetch dependency actually resolves in this environment. Don't mark `ideate` done on a copy-and-rename alone.
7. **Scripts:** port `scripts/*.py` (compound-learnings) as-is; verify stdlib-only (no compound-engineering-specific package imports) during migration.
8. **Session-kind branching:** gstack's eng/ceo review skills branch behavior on `SESSION_KIND` (`spawned` vs `headless` vs `interactive`) sourced from its preamble. superpowers has no such signal. Collapse to the `interactive` behavior path only (the common case for a human-invoked skill) and drop the `spawned`/`headless` branches; note in a code comment-equivalent (body prose) that this was intentionally simplified, so a future porter isn't confused by a reference to a mode that can never be set. This collapse assumes these two skills are always invoked directly by a human during planning, before any subagent dispatch begins — explicitly state that assumption in each skill's body, since it's the reason dropping `spawned`/`headless` is safe rather than a loss of coverage.

## Migration plan

Reordered from the original draft: `compound-learnings` now lands first because `office-hours`/`plan-ceo-review`/`plan-eng-review`'s context-gathering step (Decision 4) searches its `docs/solutions/`/`CONCEPTS.md` wiki as primary source — those three can't reference a wiki that doesn't exist yet.

**Phase 1 — compound-learnings (ex-ce-compound), ideate (ex-ce-ideate)**
1. Copy `references/` and `scripts/` verbatim under the renamed skill directories.
2. Rewrite `SKILL.md` frontmatter to two fields; drop `argument-hint` (that's a slash-command artifact — superpowers invokes skills via the `Skill` mechanism/description-matching, not positional args, so any argument-parsing prose in the body should be reframed as "if the user mentions X, do Y" rather than a CLI signature).
3. Cross-link `ideate` ↔ `brainstorming` and `compound-learnings` ↔ `writing-skills`, including the graduation path from the wiki-consultation table above ("a `docs/solutions/` entry that keeps recurring across projects is a signal it should become a skill instead").
4. Pressure-test both via `writing-skills`' subagent methodology before merging.

**Phase 2 — office-hours, plan-ceo-review, plan-eng-review**
1. Copy `sections/*.md` (not `.tmpl`) into each skill directory — flat next to `SKILL.md` if 1-2 files, a `references/` subfolder if more, matching whichever pattern the receiving skill's file count warrants (superpowers doesn't use `references/` uniformly — e.g. `writing-skills/` nests `examples/` but most skills keep supporting files flat).
2. Rewrite each `SKILL.md`: strip frontmatter to `name`/`description`; delete the "Preamble (run first)" block; replace `gbrain` context-gathering with the two-tier wiki-then-specs/git-log step (Decision 4); replace the passive section-manifest's gstack `$schema` and re-point `sections/*.md` references to the new paths; collapse `SESSION_KIND` branches to interactive-only (Decision 8); rewrite the description field to "Use when..." form per `writing-skills`.
3. Add a short "See also" line in each: `office-hours` → mentions `brainstorming`/`writing-plans` as next steps; `plan-ceo-review` and `plan-eng-review` → mention `office-hours` as a useful predecessor (carrying forward `benefits-from` as prose) and each other as companion reviews.
4. Run each rewritten skill through the `writing-skills` TDD loop (pressure-test with a subagent, since none of these three have ever been tested against superpowers' own bar) before merging.

**Phase 3 — wiki consultation retrofits + integration polish**
1. Apply the wiki-consultation edits from the table above to `systematic-debugging`, `writing-plans`, `brainstorming`, `finishing-a-development-branch`, `requesting-code-review`, `receiving-code-review`, and `writing-skills`. Each is a small, additive step/paragraph — not a rewrite of the skill's core methodology — but these are already-tuned, frequently-triggered skills. Pressure-test each edit per `writing-skills` (baseline vs. with-the-addition, per its RED/GREEN methodology) before merging rather than assuming an additive line is automatically safe.
2. Update `skills/using-superpowers/SKILL.md`'s "Skill Priority" section if the new skills change the recommended ordering for "let's build X" / "help me think through an idea" style requests (likely: office-hours before brainstorming when the idea's *worth* is in question).
3. Update root `README.md` skill list/table.
4. Bump the version in `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` (minor bump — new skills, no breaking changes). `RELEASE-NOTES.md` and the automated cross-file `scripts/bump-version.sh` were both removed in the personal-use cleanup pass, so this is now a manual, two-file edit — no changelog entry needed for a personal fork.
5. No hook changes needed — `hooks/session-start` only injects `using-superpowers`, which is unaffected structurally.

## Explicitly out of scope

- Porting gstack's `bin/gstack-*` CLI, `~/.gstack` global brain, or its `.tmpl`/codegen build pipeline into superpowers. That's gstack's product, not a skill.
- Porting any other gstack or compound-engineering skills beyond the five named. (`ce-brainstorm`, `ce-plan`, `ce-debug`, etc. have their own overlap questions with superpowers' existing `brainstorming`/`writing-plans`/`systematic-debugging` and are out of scope for this pass.)
- Adding a `benefits-from` or `gbrain`-style frontmatter field to superpowers' skill schema. Three skills' worth of soft-chaining doesn't justify extending the shared contract; prose cross-references suffice.
- Renaming `plan-ceo-review`/`plan-eng-review` to match `requesting-code-review`/`receiving-code-review` — considered and rejected; see Decision 2.
