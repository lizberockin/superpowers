# Phase 1: Port compound-learnings and ideate Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port `compound-engineering`'s `ce-compound` and `ce-ideate` skills into this superpowers fork as `compound-learnings` and `ideate` — self-contained, portable across any project, with no dangling references to compound-engineering skills that aren't being ported.

**Architecture:** Copy each skill's `references/`, `scripts/`, `assets/` verbatim, then rewrite `SKILL.md` frontmatter to superpowers' two-field contract and fix every place the original content assumed the rest of the compound-engineering plugin suite exists (a `ce-compound-refresh` companion skill, a `ce-brainstorm`/`ce-plan` pipeline, a `ce-proof` external publishing integration, and a Rails-specific documentation schema). Nothing here builds new infrastructure — it's a content port with targeted fixes.

**Tech Stack:** Markdown skill files, YAML frontmatter/schema, Python (stdlib-only) validation scripts, Bash. This is a documentation/content migration, not application code — "tests" in this plan are grep-verification steps (confirm no stale references remain) and skill pressure-tests via `writing-skills`' subagent methodology (confirm the agent actually follows the rewritten skill correctly), not unit tests.

## Global Constraints

- Frontmatter on both new skills: exactly two fields, `name` and `description`. `description` in third-person "Use when..." form per `writing-skills`. (Source: integration spec, Decision 3.)
- No references to gstack or to any compound-engineering skill beyond `ce-compound`/`ce-ideate` may survive the port — specifically `ce-compound-refresh`, `ce-brainstorm`, `ce-plan`, `ce-proof`, `ce-simplify-code` are **not** being ported and must not be invoked or treated as available. (Source: integration spec, "Explicitly out of scope"; this plan's own recon below.)
- `compound-learnings`' documentation schema (`references/schema.yaml`) must not assume any particular tech stack (found: it was Rails-specific) — this skill needs to work across every project the user works in. (Source: user's stated goal in the integration spec's Goal section.)
- Scripts must remain stdlib-only Python / plain Bash — verified true of the source files during recon; re-verify after copy. (Source: integration spec, Decision 7.)
- `ideate` needs its Slack/issue-tracker-dependent subagents explicitly tested for graceful degradation when those tools are absent — not assumed to work from a copy alone. (Source: integration spec, Decision 6 note.)

---

## Task 1: Scaffold `skills/compound-learnings/` from `ce-compound`

**Files:**
- Create: `skills/compound-learnings/SKILL.md` (copy of `/Users/lizbrokken/AI/compound-engineering/skills/ce-compound/SKILL.md`)
- Create: `skills/compound-learnings/references/schema.yaml`
- Create: `skills/compound-learnings/references/yaml-schema.md`
- Create: `skills/compound-learnings/references/grounding-validation.md`
- Create: `skills/compound-learnings/references/concepts-vocabulary.md`
- Create: `skills/compound-learnings/references/agents/best-practices-researcher.md`
- Create: `skills/compound-learnings/references/agents/data-integrity-guardian.md`
- Create: `skills/compound-learnings/references/agents/framework-docs-researcher.md`
- Create: `skills/compound-learnings/references/agents/pattern-recognition-specialist.md`
- Create: `skills/compound-learnings/references/agents/performance-oracle.md`
- Create: `skills/compound-learnings/references/agents/security-sentinel.md`
- Create: `skills/compound-learnings/references/agents/session-historian.md`
- Create: `skills/compound-learnings/scripts/validate-doc-claims.py`
- Create: `skills/compound-learnings/scripts/validate-frontmatter.py`
- Create: `skills/compound-learnings/scripts/session-history/discover-sessions.sh`
- Create: `skills/compound-learnings/scripts/session-history/extract-errors.py`
- Create: `skills/compound-learnings/scripts/session-history/extract-metadata.py`
- Create: `skills/compound-learnings/scripts/session-history/extract-skeleton.py`
- Create: `skills/compound-learnings/assets/resolution-template.md`

- [ ] **Step 1: Copy the directory verbatim**

```bash
mkdir -p skills/compound-learnings
cp -R /Users/lizbrokken/AI/compound-engineering/skills/ce-compound/. skills/compound-learnings/
chmod +x skills/compound-learnings/scripts/session-history/discover-sessions.sh
```

- [ ] **Step 2: Verify the file count matches the source (19 files)**

Run: `find skills/compound-learnings -type f | wc -l`
Expected: `19`

- [ ] **Step 3: Verify scripts are stdlib-only**

Run: `grep -rn "^import\|^from" skills/compound-learnings/scripts/`
Expected: only `os`, `re`, `sys`, `subprocess`, `argparse`, `io`, `json` — no third-party packages. (Already confirmed true of the source during spec recon; this step re-confirms nothing changed in the copy.)

- [ ] **Step 4: Commit the raw copy before any edits**

```bash
git add skills/compound-learnings
git commit -m "Copy ce-compound into skills/compound-learnings (unmodified)

Raw copy from compound-engineering, prior to renaming and stripping
compound-engineering-suite-specific references. Subsequent commits
rewrite this in place."
```

(Committing the raw copy first, before edits, means the diff in later steps shows exactly what changed — useful for review.)

---

## Task 2: Rewrite `compound-learnings/SKILL.md` frontmatter

**Files:**
- Modify: `skills/compound-learnings/SKILL.md:1-4`

- [ ] **Step 1: Replace the frontmatter block**

Old:
```markdown
---
name: ce-compound
description: Document a recently solved problem or durable project vocabulary in docs/solutions/ or CONCEPTS.md. Use when capturing a learning after work.
argument-hint: "[optional: brief context] [mode:headless] [depth:lightweight|full]"
---
```

New:
```markdown
---
name: compound-learnings
description: Use when a problem was just solved, a durable project convention was established, or project-specific vocabulary emerged — captures it as searchable documentation in docs/solutions/ or CONCEPTS.md before the context is lost.
---
```

- [ ] **Step 2: Replace the `# /ce-compound` heading**

Old: `# /ce-compound`
New: `# Compound Learnings`

(The leading `/` implied a slash command. This skill is invoked via natural language / the `Skill` tool, not a slash command — drop the slash-command framing throughout, per Task 3.)

---

## Task 3: Remove `ce-compound-refresh`/`ce-simplify-code` dependencies and self-rename in `compound-learnings/SKILL.md`

`ce-compound-refresh` (a companion skill that builds/refreshes a repo-wide concept map) and `ce-simplify-code` (a code-simplification skill) are both explicitly out of scope for this port (integration spec, "Explicitly out of scope"). `ce-compound`'s SKILL.md assumes both exist. This task removes every assumption that they're invokable, and separately renames the skill's remaining self-references from `ce-compound` to `compound-learnings`.

**Files:**
- Modify: `skills/compound-learnings/SKILL.md`

**Rule for this task:** every literal occurrence of `ce-compound-refresh` must be either removed or rephrased so the sentence reads correctly with no such skill existing. Every literal occurrence of bare `ce-compound` (not part of `ce-compound-refresh`) referring to *this skill itself* becomes `compound-learnings`, **except** the scratch-directory path literals (`$SCRATCH_ROOT/ce-compound/$RUN_ID`, `SCRATCH=$(mktemp -d -t ce-compound-sessions-XXXXXX)`) — leave those two exactly as-is. They're internal temp-folder naming, invisible to the user, and renaming them has no functional benefit but does risk breaking the script that reads them back.

- [ ] **Step 1: Fix the CONCEPTS.md bootstrap-redirect paragraph**

Old:
```markdown
If invoked specifically to create or bootstrap `CONCEPTS.md` from scratch rather than to document a solved problem, do not run the normal phases — `ce-compound` populates `CONCEPTS.md` only as a side effect of documenting a real learning (it seeds the *learning's area*, not the whole repo; see Phase 2.4). Repo-wide concept-map creation is `ce-compound-refresh`'s job. Redirect a standalone bootstrap request to `ce-compound-refresh` (which asks whether to build the concept map or run a refresh cycle), then exit.
```

New:
```markdown
If invoked specifically to create or bootstrap `CONCEPTS.md` from scratch rather than to document a solved problem, do not run the normal phases — `compound-learnings` populates `CONCEPTS.md` only as a side effect of documenting a real learning (it seeds the *learning's area*, not the whole repo; see Phase 2.4). Building a repo-wide concept map from scratch is out of scope for this skill. Tell the user that directly — this skill only seeds `CONCEPTS.md` incrementally as real problems get documented — and exit.
```

- [ ] **Step 2: Fix the mode-detection self-reference**

Old (within the Mode Detection paragraph): `a caller or standing instruction asking to run \`ce-compound\` "headless", "non-interactively", "unattended", or "without prompts/questions"`
New: `a caller or standing instruction asking to run \`compound-learnings\` "headless", "non-interactively", "unattended", or "without prompts/questions"`

- [ ] **Step 3: Replace the slash-command usage block**

Old:
```markdown
## Usage

```bash
/ce-compound                            # Document the most recent fix
/ce-compound [brief context]            # Provide additional context hint
/ce-compound mode:headless              # Non-interactive run for automations
/ce-compound mode:headless [context]    # Non-interactive run with context hint
/ce-compound mode:headless depth:lightweight [context] # Lower-overhead non-interactive run
/ce-compound mode:headless depth:full [context]        # Full non-interactive run
```
```

New:
```markdown
## Usage

Invoke by describing what you want, same as any other skill:

- "document that fix" / "capture that as a learning" — document the most recent fix
- "document that fix — it was about the retry logic timing out" — with a context hint
- "document that headless" / "run compound-learnings headless" — non-interactive run for automations
- "document that headless, lightweight" — lower-overhead non-interactive run
- "document that headless, full" — full non-interactive run
```

- [ ] **Step 4: Fix the "why no interactive mode question" paragraph**

Old: `` `ce-compound` does not ask the user which mode to run or whether to search session history. ``
New: `` `compound-learnings` does not ask the user which mode to run or whether to search session history. ``

- [ ] **Step 5: Fix the CONCEPTS.md seed-preamble template**

This one matters more than the others — it's literal text the skill writes into a *target project's* `CONCEPTS.md` file the first time it bootstraps one. Leaving `ce-compound-refresh` in it would plant a dangling reference into every project this skill touches.

Old:
```markdown
**When bootstrapping the file, start with this preamble under the `# Concepts` heading**, then add the qualifying entries below it:

> Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as ce-compound and ce-compound-refresh process learnings; direct edits are fine. Glossary only, not a spec or catch-all.
```

New:
```markdown
**When bootstrapping the file, start with this preamble under the `# Concepts` heading**, then add the qualifying entries below it:

> Shared domain vocabulary for this project — entities, named processes, and status concepts with project-specific meaning. Seeded with core domain vocabulary, then accretes as compound-learnings processes new learnings; direct edits are fine. Glossary only, not a spec or catch-all.
```

- [ ] **Step 6: Fix the two "flag for ce-compound-refresh" sentences in the coherence-neighborhood paragraph**

Old (two occurrences in the same paragraph):
```markdown
...if judging a neighbor would require investigation this learning did not do, flag it for `ce-compound-refresh` rather than editing on a guess. The test: after the edit, would a reader find the touched entry's siblings or referenced terms inconsistent with it? Broader audit is `ce-compound-refresh`'s job.
```

New:
```markdown
...if judging a neighbor would require investigation this learning did not do, note it in the terminal report as a candidate for manual follow-up rather than editing on a guess. The test: after the edit, would a reader find the touched entry's siblings or referenced terms inconsistent with it? A broader audit of the whole file is out of scope for this skill.
```

- [ ] **Step 7: Fix the "repo-wide concept map is ce-compound-refresh's bootstrap path" sentence**

Old: `A repo-wide concept map is \`ce-compound-refresh\`'s bootstrap path, not this one.`
New: `A repo-wide concept map is out of scope for this skill — it only ever seeds the area a real learning touched.`

- [ ] **Step 8: Rewrite the Phase 2.5 "Selective Refresh Check" section**

Old:
```markdown
### Phase 2.5: Selective Refresh Check

After writing the new learning, decide whether this new solution is evidence that older docs should be refreshed.

`ce-compound-refresh` is **not** a default follow-up. Use it selectively when the new learning suggests an older learning or pattern doc may now be inaccurate.

It makes sense to invoke `ce-compound-refresh` when one or more of these are true:

1. A related learning or pattern doc recommends an approach that the new fix now contradicts
2. The new fix clearly supersedes an older documented solution
3. The current work involved a refactor, migration, rename, or dependency upgrade that likely invalidated references in older docs
4. A pattern doc now looks overly broad, outdated, or no longer supported by the refreshed reality
5. The Related Docs Finder surfaced high-confidence refresh candidates in the same problem space
6. The Related Docs Finder reported **moderate overlap** with an existing doc — there may be consolidation opportunities that benefit from a focused review

It does **not** make sense to invoke `ce-compound-refresh` when:

1. No related docs were found
2. Related docs still appear consistent with the new learning
3. The overlap is superficial and does not change prior guidance
4. Refresh would require a broad historical review with weak evidence

Use these rules:

- If there is **one obvious stale candidate**, invoke `ce-compound-refresh` with a narrow scope hint after the new learning is written
- If there are **multiple candidates in the same area**, ask the user whether to run a targeted refresh for that module, category, or pattern set
- If context is already tight or you are in lightweight mode, do not expand into a broad refresh automatically; instead recommend `ce-compound-refresh` as the next step with a scope hint
- **In headless mode**, never invoke `ce-compound-refresh` and never ask the user. Surface the recommended scope hint in the terminal report's "Refresh recommendation" line and let the caller decide

When invoking or recommending `ce-compound-refresh`, be explicit about the argument to pass. Prefer the narrowest useful scope:

- **Specific file** when one learning or pattern doc is the likely stale artifact
- **Module or component name** when several related docs may need review
- **Category name** when the drift is concentrated in one solutions area
- **Pattern filename or pattern topic** when the stale guidance lives in `docs/solutions/patterns/`

Examples:

- `/ce-compound-refresh plugin-versioning-requirements`
- `/ce-compound-refresh payments`
- `/ce-compound-refresh performance-issues`
- `/ce-compound-refresh critical-patterns`

A single scope hint may still expand to multiple related docs when the change is cross-cutting within one domain, category, or pattern area.

Do not invoke `ce-compound-refresh` without an argument unless the user explicitly wants a broad sweep.
```

New:
```markdown
### Phase 2.5: Selective Staleness Check

After writing the new learning, decide whether this new solution is evidence that older docs are now stale. There is no companion refresh skill in this library to hand this off to — `compound-learnings` only ever flags staleness, it never rewrites another doc automatically. Rewriting other docs' guidance is a bigger, riskier action than documenting the current learning, and doing it well needs its own grounding pass against each stale candidate — a job for a deliberate, separate follow-up, not a side effect of this run.

Flag a candidate when one or more of these are true:

1. A related learning or pattern doc recommends an approach that the new fix now contradicts
2. The new fix clearly supersedes an older documented solution
3. The current work involved a refactor, migration, rename, or dependency upgrade that likely invalidated references in older docs
4. A pattern doc now looks overly broad, outdated, or no longer supported by the refreshed reality
5. The Related Docs Finder surfaced high-confidence refresh candidates in the same problem space
6. The Related Docs Finder reported **moderate overlap** with an existing doc — there may be consolidation opportunities that benefit from a focused review

Don't flag anything when:

1. No related docs were found
2. Related docs still appear consistent with the new learning
3. The overlap is superficial and does not change prior guidance
4. A proper assessment would require a broad historical review with weak evidence — don't speculate

Use these rules:

- If there is **one obvious stale candidate**, note it in the terminal report's "Refresh recommendation" line with a narrow scope hint, so the user can act on it as a separate, deliberate step.
- If there are **multiple candidates in the same area** and you're in interactive mode, ask the user whether they want to open and update one of the stale docs now, as a follow-up after this run.
- If context is already tight or you are in lightweight mode, skip this check entirely — a lightweight run's job is the new doc, not a quality sweep of old ones.
- **In headless mode**, never ask the user. Surface every recommended scope hint in the terminal report's "Refresh recommendation" line and let the caller decide.

When flagging a candidate, be explicit about the scope. Prefer the narrowest useful description:

- **Specific file** when one learning or pattern doc is the likely stale artifact
- **Module or component name** when several related docs may need review
- **Category name** when the drift is concentrated in one solutions area
- **Pattern filename or pattern topic** when the stale guidance lives in `docs/solutions/patterns/`

Examples of a scope hint: "the plugin-versioning-requirements doc", "the payments category", "the performance-issues docs", "the critical-patterns doc".

A single scope hint may still point at multiple related docs when the change is cross-cutting within one domain, category, or pattern area.
```

- [ ] **Step 9: Fix the lightweight-mode overlap-check aside**

Old: `That is acceptable — \`ce-compound-refresh\` will catch it later. Only suggest \`ce-compound-refresh\` if there is an obvious narrow refresh target. Do not broaden into a large refresh sweep from a lightweight session.`
New: `That is acceptable — flag it in the terminal report if it's an obvious narrow case, and leave it for a later, deliberate pass otherwise. Do not broaden into a large refresh sweep from a lightweight session.`

- [ ] **Step 10: Fix the terminal-report template line**

Old: `Refresh recommendation: <none | scope hint for /ce-compound-refresh>`
New: `Refresh recommendation: <none | scope hint>`

- [ ] **Step 11: Fix the `ce-simplify-code` mention**

Old: `- **Manual trigger**: User can run surviving skills such as \`ce-simplify-code\` after \`/ce-compound\` completes for deeper code review and mutation`
New: `- **Manual trigger**: after this completes, the user can separately ask for a deeper code-quality pass over the change (e.g. superpowers:requesting-code-review) if they want one — this skill doesn't do that itself.`

- [ ] **Step 12: Fix the remaining bare self-references**

Old: `` Apply edits only to the documentation/examples being written by `ce-compound`; leave any branch code changes untouched. ``
New: `` Apply edits only to the documentation/examples being written by `compound-learnings`; leave any branch code changes untouched. ``

Old: `semantic grounding validation), re-run /ce-compound in a fresh session.`
New: `semantic grounding validation), re-run compound-learnings in a fresh session.`

Old: `<manual_override> Use /ce-compound [context] to document immediately without waiting for auto-detection. </manual_override> </auto_invoke>`
New: `<manual_override> Ask for compound-learnings by name, with context, to document immediately without waiting for auto-detection. </manual_override> </auto_invoke>`

- [ ] **Step 13: Verify no dangling references remain**

Run: `grep -n "ce-compound-refresh\|ce-simplify-code" skills/compound-learnings/SKILL.md`
Expected: no output.

Run: `grep -n "ce-compound\b" skills/compound-learnings/SKILL.md`
Expected: exactly two hits — the two scratch-path literals from Task 1's exclusion rule (`RUN_DIR="$SCRATCH_ROOT/ce-compound/$RUN_ID"` and `mktemp -d -t ce-compound-sessions-XXXXXX`). If there are more, an earlier step was missed — go back and fix it.

- [ ] **Step 14: Commit**

```bash
git add skills/compound-learnings/SKILL.md
git commit -m "Rename compound-learnings self-references, remove ce-compound-refresh/ce-simplify-code deps

Neither companion skill is being ported. Staleness detection now
flags candidates in the terminal report instead of auto-invoking or
recommending a skill that doesn't exist here."
```

---

## Task 4: Genericize the documentation schema (Rails → framework-neutral)

Recon finding: `references/schema.yaml`'s `component` field is a closed enum hardcoded to Rails concepts (`rails_model`, `rails_controller`, `frontend_stimulus`, `hotwire_turbo`, ...), and `rails_version` is a Rails-specific optional field. Neither survives contact with a non-Rails project — and per the integration spec's Goal, this skill needs to work across every project the user works in, not just Ruby-on-Rails ones. `validate-frontmatter.py` does not enforce this enum (confirmed during recon: it's parser-safety-only, no schema/enum validation), so this is a pure documentation fix, not a script change.

**Files:**
- Modify: `skills/compound-learnings/references/schema.yaml`
- Modify: `skills/compound-learnings/references/yaml-schema.md`

- [ ] **Step 1: Replace the `component` field definition in `schema.yaml`**

Old:
```yaml
  component:
    type: enum
    values:
      - rails_model
      - rails_controller
      - rails_view
      - service_object
      - background_job
      - database
      - frontend_stimulus
      - hotwire_turbo
      - email_processing
      - brief_system
      - assistant
      - authentication
      - payments
      - development_workflow
      - testing_framework
      - documentation
      - tooling
    description: "Component involved"
```

New:
```yaml
  component:
    type: string
    description: "Component or area involved, e.g. \"backend\", \"frontend\", \"database\", \"cli\", \"infra\", \"api\", \"build-tooling\". Free text — use whatever component taxonomy fits this project; there is no fixed enum, since this schema travels across unrelated projects."
```

- [ ] **Step 2: Replace the `rails_version` field definition in `schema.yaml`**

Old:
```yaml
# --- Fields optional for bug track only -------------------------------------
bug_optional_fields:
  rails_version:
    type: string
    pattern: '^\d+\.\d+\.\d+$'
    description: "Rails version in X.Y.Z format. Only relevant for bug-track docs."
```

New:
```yaml
# --- Fields optional for bug track only -------------------------------------
bug_optional_fields:
  framework_version:
    type: string
    description: "Framework or runtime version relevant to this bug, if applicable (e.g. \"Rails 7.1.2\", \"Node 20.11.0\", \"Python 3.12\"). Omit entirely when no single framework/runtime version is relevant."
```

- [ ] **Step 3: Update the validation-rules line referencing `rails_version`**

Old: `  - "rails_version, if provided, must match X.Y.Z format and only applies to bug-track docs"`
New: `  - "framework_version, if provided, only applies to bug-track docs; free text, no fixed format"`

- [ ] **Step 4: Update `yaml-schema.md` to match**

Old: `` - **component**: One of `rails_model`, `rails_controller`, `rails_view`, `service_object`, `background_job`, `database`, `frontend_stimulus`, `hotwire_turbo`, `email_processing`, `brief_system`, `assistant`, `authentication`, `payments`, `development_workflow`, `testing_framework`, `documentation`, `tooling` ``
New: `` - **component**: Free text — component or area involved (e.g. `backend`, `frontend`, `database`, `cli`, `infra`) ``

Old: `` - **rails_version**: Rails version in `X.Y.Z` format ``
New: `` - **framework_version**: Framework/runtime version, if relevant to this bug (e.g. `Rails 7.1.2`, `Node 20.11.0`) ``

Old: `` 9. `rails_version`, if present, must match `X.Y.Z` and only applies to bug-track docs. ``
New: `` 9. `framework_version`, if present, only applies to bug-track docs — free text, no fixed format. ``

- [ ] **Step 5: Verify no Rails-specific terms remain**

Run: `grep -in "rails\|hotwire\|stimulus" skills/compound-learnings/references/schema.yaml skills/compound-learnings/references/yaml-schema.md`
Expected: no output.

- [ ] **Step 6: Commit**

```bash
git add skills/compound-learnings/references/schema.yaml skills/compound-learnings/references/yaml-schema.md
git commit -m "Genericize compound-learnings documentation schema

component becomes free text instead of a Rails-locked enum;
rails_version becomes framework_version. validate-frontmatter.py
doesn't enforce either field, so this is documentation-only —
confirmed the script is parser-safety-only, not schema validation."
```

---

## Task 5: Cross-link `compound-learnings` ↔ `writing-skills`

Per the integration spec (Phase 1 step 3, and the "Wiki consultation points" table's `writing-skills` row — the same edit satisfies both, so it's done once here rather than repeated in the later wiki-retrofit work).

**Files:**
- Modify: `skills/compound-learnings/SKILL.md` (add a "See also" note near the top)
- Modify: `skills/writing-skills/SKILL.md` (add a boundary note)

- [ ] **Step 1: Add a "See also" note to `compound-learnings/SKILL.md`**

Insert directly after the `# Compound Learnings` heading (before `## Purpose` or the first content section):

```markdown

**See also:** `superpowers:writing-skills` — this skill documents a *one-off solved problem*, scoped to `docs/solutions/`. If the same technique keeps recurring across unrelated projects, that's a signal it should become a portable skill instead of another solutions doc — see `writing-skills` for that path.
```

- [ ] **Step 2: Add the reciprocal boundary note to `writing-skills/SKILL.md`**

Read `skills/writing-skills/SKILL.md`'s "When to Create a Skill" section first to find the right insertion point (directly after the existing "Don't create for:" bullet list is the natural spot). Insert:

```markdown

**Boundary with `compound-learnings`:** a one-off solved problem, scoped to one project, belongs in `docs/solutions/` via `superpowers:compound-learnings` — not here. Create a skill only once the same technique has recurred across unrelated projects; a `docs/solutions/` entry that keeps coming up in different repos is exactly that signal.
```

- [ ] **Step 3: Commit**

```bash
git add skills/compound-learnings/SKILL.md skills/writing-skills/SKILL.md
git commit -m "Cross-link compound-learnings and writing-skills

States the boundary between a one-off solved-problem writeup and a
portable reusable skill, with a graduation signal (recurrence across
projects) pointing from one to the other."
```

---

## Task 6: Scaffold `skills/ideate/` from `ce-ideate`

**Files:**
- Create: `skills/ideate/SKILL.md`
- Create: `skills/ideate/references/post-ideation-workflow.md`
- Create: `skills/ideate/references/web-research-cache.md`
- Create: `skills/ideate/references/ideation-sections.md`
- Create: `skills/ideate/references/markdown-rendering.md`
- Create: `skills/ideate/references/html-rendering.md`
- Create: `skills/ideate/references/divergent-ideation.md`
- Create: `skills/ideate/references/universal-ideation.md`
- Create: `skills/ideate/references/agents/issue-intelligence-analyst.md`
- Create: `skills/ideate/references/agents/learnings-researcher.md`
- Create: `skills/ideate/references/agents/slack-researcher.md`
- Create: `skills/ideate/references/agents/web-researcher.md`

- [ ] **Step 1: Copy the directory verbatim**

```bash
mkdir -p skills/ideate
cp -R /Users/lizbrokken/AI/compound-engineering/skills/ce-ideate/. skills/ideate/
```

- [ ] **Step 2: Verify the file count matches the source (12 files)**

Run: `find skills/ideate -type f | wc -l`
Expected: `12`

- [ ] **Step 3: Commit the raw copy before any edits**

```bash
git add skills/ideate
git commit -m "Copy ce-ideate into skills/ideate (unmodified)

Raw copy from compound-engineering, prior to renaming and remapping
the ce-brainstorm/ce-proof handoffs to superpowers equivalents."
```

---

## Task 7: Rewrite `ideate/SKILL.md` frontmatter and self-references

**Files:**
- Modify: `skills/ideate/SKILL.md`

- [ ] **Step 1: Replace the frontmatter block**

Old:
```markdown
---
name: ce-ideate
description: "Generate and evaluate grounded ideas. Use when the user asks for ideas, improvements, surprising options, or AI-generated directions before choosing one to develop; use ce-brainstorm to refine the user's own idea."
argument-hint: "[feature, focus area, or constraint] [output:md]"
---
```

New:
```markdown
---
name: ideate
description: Use when the user asks for ideas, improvements, surprising options, or AI-generated directions before choosing one to develop — generates and evaluates grounded ideas via parallel research subagents. Use brainstorming instead to refine an idea the user already has in mind.
---
```

- [ ] **Step 2: Fix the relationship-to-brainstorming statement**

Old (near the top of the file, describing how the two skills relate):
```markdown
`ce-ideate` precedes `ce-brainstorm`.

- `ce-ideate` answers: "What are the strongest ideas worth exploring?"
```

New:
```markdown
`ideate` precedes `brainstorming`.

- `ideate` answers: "What are the strongest ideas worth exploring?"
```

- [ ] **Step 3: Fix the output-format comparison sentence**

Old: `` Unlike `ce-plan` and `ce-brainstorm` (which default to `md`), ce-ideate defaults to **`html`** — ideation artifacts are read mainly by humans weighing candidate directions... ``
New: `` Unlike `writing-plans` and `brainstorming` (which default to `md`), ideate defaults to **`html`** — ideation artifacts are read mainly by humans weighing candidate directions... ``

- [ ] **Step 4: Leave the scratch-directory path literals unchanged**

`SCRATCH_DIR="$SCRATCH_ROOT/ce-ideate/<run-id>"` and its neighboring line stay exactly as-is — same reasoning as compound-learnings' scratch paths in Task 3 (internal temp-folder naming, no functional benefit to renaming, risk of breaking the read-back path).

- [ ] **Step 5: Verify frontmatter and self-references**

Run: `head -5 skills/ideate/SKILL.md`
Expected: the new two-field frontmatter block from Step 1.

Run: `grep -n "ce-ideate\b" skills/ideate/SKILL.md`
Expected: exactly the two scratch-path hits from Step 4. If more, an earlier step was missed.

- [ ] **Step 6: Commit**

```bash
git add skills/ideate/SKILL.md
git commit -m "Rewrite ideate frontmatter and fix self/ce-plan/ce-brainstorm references in SKILL.md body"
```

---

## Task 8: Remap the `ce-brainstorm` handoff and remove `ce-proof` in `post-ideation-workflow.md`

Recon finding: `ce-ideate`'s "what next?" menu hands off to `ce-brainstorm` (a different skill than superpowers' `brainstorming`, with a different output shape — a "requirements-only unified plan under `docs/plans/`" vs. `brainstorming`'s dialogue-driven design doc at `docs/superpowers/specs/`) and offers to publish markdown output to "Proof", an external compound-engineering/Every.to publishing service reached via the unported `ce-proof` skill. Both need real rewrites, not a find-replace — the interfaces differ.

**Files:**
- Modify: `skills/ideate/references/post-ideation-workflow.md`

- [ ] **Step 1: Rewrite the Phase 5 menu's option 1 and option 2**

Old:
```markdown
1. *(when `OUTPUT_FORMAT=html`)* **Open in browser** — open the saved HTML deliverable (re-open if it was already opened).
   *(when `OUTPUT_FORMAT=md`)* **Publish to Proof** — publish the saved markdown to Proof and get a shareable link; one-way, the local file stays canonical.
2. **Brainstorm one idea with `ce-brainstorm`** — commit a chosen idea to a requirements-only unified plan under `docs/plans/`; leaves ce-ideate. Asks which idea first.
3. **Discuss or refine the ideas first** — stay here to think across the set before committing: adjust or interrogate one idea, compare several, or combine/merge them. Asks what you want to work on.
4. **Done — keep the file and stop.**
```

New:
```markdown
1. *(when `OUTPUT_FORMAT=html`, otherwise this option is omitted and the menu has three options)* **Open in browser** — open the saved HTML deliverable (re-open if it was already opened).
2. **Brainstorm one idea with `brainstorming`** — hand the chosen idea to superpowers' `brainstorming` skill to turn into an approved design. Leaves `ideate`. Asks which idea first.
3. **Discuss or refine the ideas first** — stay here to think across the set before committing: adjust or interrogate one idea, compare several, or combine/merge them. Asks what you want to work on.
4. **Done — keep the file and stop.**
```

(There's no markdown-mode equivalent of "Open in browser" once Proof is gone — the Stem line just above this menu already surfaces the saved path ("Your ideation is saved to `<path>`"), so markdown mode drops straight to a three-option menu instead of carrying a dead first option.)

- [ ] **Step 2: Rewrite the `### 5.1` section**

Old:
```markdown
### 5.1 Open in Browser (html) / Publish to Proof (md)

- **HTML — Open in browser.** (Re)open the saved file via the platform primitive where available; otherwise print the absolute path. Return to the Phase 5 menu. No Proof — the HTML file is the canonical record.
- **Markdown — Publish to Proof.** The local markdown file already exists (Phase 4) and stays canonical; Proof is a one-way published copy, not a sync target. Load the `ce-proof` skill to publish, passing:
  - **source file:** the saved `.md` file from Phase 4.
  - **doc title:** `Ideation: <topic>` or the doc's H1.
  - **identity:** `ai:compound-engineering` / `Compound Engineering`.

  ce-proof creates a shared Proof doc (Create and Share workflow) and returns the share URL. Surface it to the user, then return to the Phase 5 menu — nothing syncs back to disk. If the Proof handoff fails after the proof skill's internal retry plus one orchestrator-side retry (~2s pause, narrated as "Retrying Proof... attempt 2/2"), tell the user Proof is unavailable and that the local file is intact at `<path>`, then return to the menu — the deliverable was never at risk (it was written in Phase 4). *(If the user explicitly asked for Proof during an HTML run: Proof is markdown-only and cannot ingest HTML, so render a throwaway markdown copy of the survivors as the Proof source and do not upload the `.html`.)*
```

New:
```markdown
### 5.1 Open in Browser (html only)

- **HTML — Open in browser.** (Re)open the saved file via the platform primitive where available; otherwise print the absolute path. Return to the Phase 5 menu. The HTML file is the canonical record.
- **Markdown mode has no equivalent step.** The saved `.md` file's path was already surfaced in the Phase 5 stem — there's nothing further to do here. (There is no publishing integration in this build; the file on disk is the deliverable.)
```

- [ ] **Step 3: Fix the `ce-brainstorm` handoff instructions in `### 5.2`**

Old:
```markdown
### 5.2 Brainstorm One Idea

1. **Identify the idea** by number or name (skip if the user already named it). Match against the ranked list from Phase 4.2.
2. **Build a focused seed** from the idea's substance already in the orchestrator's context. Do **not** pass the whole file — wasteful and noisy (the other survivors, grounding, and rejection table are irrelevant to defining this one idea, and an HTML file carries CSS/SVG chrome). Do **not** pass only a file pointer — that forces `ce-brainstorm` to re-open and re-extract the idea the orchestrator already holds. The seed is feature-description-shaped:

   > `<title> — <description>. Basis: <basis/evidence>. Why it matters: <rationale>. Known tradeoffs: <downsides>.`

   The basis/evidence directly feeds `ce-brainstorm`'s product-pressure-test, so it won't re-derive what we already know. Append a one-line provenance pointer: `(Seeded from ce-ideate: <path>, idea "<title>")` — it records origin and lets brainstorm pull adjacent detail if it wants, without being forced to read anything.
3. **Load the `ce-brainstorm` skill** with that seed. The saved file is already the record — no extra write step.

**Repo mode only:** do **not** skip brainstorming and go straight to `ce-plan` — `ce-plan` wants a brainstorm-grounded Product Contract. In elsewhere modes, ideation is a legitimate terminal state; brainstorming is optional deeper development of one idea, not a required next rung on an implementation ladder that does not exist in these modes.
```

New:
```markdown
### 5.2 Brainstorm One Idea

1. **Identify the idea** by number or name (skip if the user already named it). Match against the ranked list from Phase 4.2.
2. **Build a focused seed** from the idea's substance already in the orchestrator's context. Do **not** pass the whole file — wasteful and noisy (the other survivors, grounding, and rejection table are irrelevant to defining this one idea, and an HTML file carries CSS/SVG chrome). Do **not** pass only a file pointer — that forces `brainstorming` to re-open and re-extract the idea the orchestrator already holds. The seed is feature-description-shaped:

   > `<title> — <description>. Basis: <basis/evidence>. Why it matters: <rationale>. Known tradeoffs: <downsides>.`

   Append a one-line provenance pointer: `(Seeded from ideate: <path>, idea "<title>")` — it records origin and lets brainstorming pull adjacent detail if it wants, without being forced to read anything.
3. **Invoke the `brainstorming` skill** with that seed as the starting idea. `brainstorming` runs its own normal dialogue from there (clarifying questions, 2-3 approaches, design sections) — this handoff just gives it a grounded starting point instead of a cold "let's build X".

**Repo mode only:** do **not** skip brainstorming and go straight to implementation — `writing-plans` (which `brainstorming` hands off to once its design is approved) wants an approved design behind it, not a bare idea. In elsewhere modes, ideation is a legitimate terminal state; brainstorming is optional deeper development of one idea, not a required next rung on an implementation ladder that does not exist in these modes.
```

- [ ] **Step 4: Fix the `### 5.3` self-reference**

Old: `This stays in ce-ideate — no skill handoff.`
New: `This stays in ideate — no skill handoff.`

- [ ] **Step 5: Fix the summary-bullet reference near the end of the file**

Old: `- acting on an idea routes to \`ce-brainstorm\` (with a substance seed, not the whole file), not directly to implementation`
New: `- acting on an idea routes to \`brainstorming\` (with a substance seed, not the whole file), not directly to implementation`

- [ ] **Step 6: Verify no dangling references remain**

Run: `grep -n "ce-brainstorm\|ce-proof\|ce-plan\b" skills/ideate/references/post-ideation-workflow.md`
Expected: no output.

- [ ] **Step 7: Commit**

```bash
git add skills/ideate/references/post-ideation-workflow.md
git commit -m "Remap ce-brainstorm handoff to brainstorming, remove ce-proof from ideate

Proof is compound-engineering/Every.to-specific external publishing,
not portable. The brainstorm handoff needed a real rewrite, not a
rename — brainstorming's dialogue-driven interface and output location
differ from ce-brainstorm's requirements-file model."
```

---

## Task 9: Remap `ce-brainstorm` mentions in `universal-ideation.md`

**Files:**
- Modify: `skills/ideate/references/universal-ideation.md`

- [ ] **Step 1: Fix the questioning-principles paragraph**

Old (mid-paragraph): `` never about solution direction, constraints, audience, tone, or success criteria. Those belong to `ce-brainstorm`. ``
New: `` never about solution direction, constraints, audience, tone, or success criteria. Those belong to `brainstorming`. ``

- [ ] **Step 2: Fix the Phase 5 menu duplicate in this file**

This file has its own copy of the Phase 5 menu (universal/elsewhere-mode variant). Apply the same shape change as Task 8 Step 1: option 1 becomes HTML-only, option 2 remaps to `brainstorming`.

Old:
```markdown
1. **Open in browser** *(html)* / **Publish to Proof** *(md)* — open the HTML deliverable, or publish the markdown to Proof for a shareable link (per §5.1). On Proof failure the auto-written local file stays intact.
2. **Brainstorm one idea with `ce-brainstorm`** — go deeper on one chosen idea (asks which). In universal mode this is **not** the first step of an implementation chain — there is no `ce-plan` → `ce-work` after; `ce-brainstorm` develops the idea further (a name into a brand brief, a plot into an outline, a decision into a weighed framework) and ends there. Seed it with the idea's substance + a provenance pointer (per §5.2) — not the whole file.
3. **Discuss or refine the ideas first** — stay here to think across the set before committing: adjust or interrogate one idea, compare several, or combine/merge them (per §5.3). Adjustments and merges rewrite the file; Q&A and comparison do not.
4. **Done — keep the file and stop.**
```

New:
```markdown
1. *(html only)* **Open in browser** — open the HTML deliverable (per §5.1). *(markdown mode: this option is omitted; the saved path was already surfaced in the stem.)*
2. **Brainstorm one idea with `brainstorming`** — go deeper on one chosen idea (asks which). In universal mode this is **not** the first step of an implementation chain — `brainstorming` develops the idea further (a name into a brand brief, a plot into an outline, a decision into a weighed framework) through its own normal dialogue, and ends there; there is no forced next step after. Seed it with the idea's substance + a provenance pointer (per §5.2) — not the whole file.
3. **Discuss or refine the ideas first** — stay here to think across the set before committing: adjust or interrogate one idea, compare several, or combine/merge them (per §5.3). Adjustments and merges rewrite the file; Q&A and comparison do not.
4. **Done — keep the file and stop.**
```

- [ ] **Step 3: Verify no dangling references remain**

Run: `grep -n "ce-brainstorm\|ce-proof\|ce-plan\b\|ce-work\b" skills/ideate/references/universal-ideation.md`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add skills/ideate/references/universal-ideation.md
git commit -m "Remap ce-brainstorm handoff to brainstorming in universal-ideation.md"
```

---

## Task 10: Fix terminology in `ideation-sections.md`

**Files:**
- Modify: `skills/ideate/references/ideation-sections.md`

- [ ] **Step 1: Replace the one reference**

Old:
```markdown
  architecture, sequence diagrams, and wireframes belong downstream in
  ce-brainstorm / ce-plan once a direction is chosen, not here.
```

New:
```markdown
  architecture, sequence diagrams, and wireframes belong downstream in
  brainstorming / writing-plans once a direction is chosen, not here.
```

- [ ] **Step 2: Verify**

Run: `grep -n "ce-brainstorm\|ce-plan\b" skills/ideate/references/ideation-sections.md`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add skills/ideate/references/ideation-sections.md
git commit -m "Fix ce-brainstorm/ce-plan terminology in ideation-sections.md"
```

**Note on `html-rendering.md`:** this file's mentions of `ce-plan`, `ce-work`, and `ce-doc-review` (a shared HTML-rendering-conventions reference, not unique to `ideate`) are left unchanged — deliberately, not an oversight. They're illustrative examples of what other skills' composed output looks like (a footer signature format, a consumer list), not literal invocations `ideate` makes from its own flow. A reader can still follow the HTML rendering conventions with those skills absent from this repo.

---

## Task 11: Cross-link `ideate` ↔ `brainstorming`

Per the integration spec's Overlap table: `brainstorming` is dialogue-driven: `ideate` is subagent-research-driven. Complementary entry points into the same funnel — cross-link them so the agent (and the user) knows both exist.

**Files:**
- Modify: `skills/ideate/SKILL.md`
- Modify: `skills/brainstorming/SKILL.md`

- [ ] **Step 1: Add a "See also" note to `ideate/SKILL.md`**

Insert near the top of the file, adjacent to the existing `ideate`/`brainstorming` relationship statement fixed in Task 7 Step 2:

```markdown

**See also:** `superpowers:brainstorming` — use `brainstorming` when the user already has an idea in mind and wants to refine it through dialogue. Use `ideate` when they want AI-generated options first, via parallel research, before picking a direction to hand to `brainstorming`.
```

- [ ] **Step 2: Add the reciprocal note to `brainstorming/SKILL.md`**

Read `skills/brainstorming/SKILL.md` first to find a natural insertion point (near the top, close to the existing overview/checklist, not buried mid-process). Insert:

```markdown

**See also:** `superpowers:ideate` — if the user wants AI-generated ideas or options rather than help refining an idea they already have, use `ideate` first; it dispatches parallel research subagents and hands the chosen direction back here.
```

- [ ] **Step 3: Commit**

```bash
git add skills/ideate/SKILL.md skills/brainstorming/SKILL.md
git commit -m "Cross-link ideate and brainstorming as complementary idea-generation entry points"
```

---

## Task 12: Pressure-test `compound-learnings`

Per `writing-skills`' TDD-for-docs methodology: verify an agent given this skill actually follows it correctly, since none of this content has been tested against superpowers' own bar before.

**Files:** none (this task produces no file changes unless testing surfaces a bug, in which case fix it and re-verify)

- [ ] **Step 1: Set up a scratch test repo**

```bash
mkdir -p /tmp/compound-learnings-test && cd /tmp/compound-learnings-test
git init -q
echo "# Test project" > README.md
git add README.md && git commit -q -m "init"
```

- [ ] **Step 2: Dispatch a subagent to invoke `compound-learnings` on a fabricated solved problem**

Use the `Agent` tool (general-purpose) with a prompt describing a small, concrete fabricated bug-fix scenario in `/tmp/compound-learnings-test` (e.g. "we just fixed a bug where X caused Y, here's the diff...") and ask it to document the learning using the `compound-learnings` skill. Run in the foreground so you can inspect the result before proceeding.

- [ ] **Step 3: Verify the output**

Check:
- A file was created under `/tmp/compound-learnings-test/docs/solutions/<category>/<name>.md` with YAML frontmatter.
- The frontmatter's `component` field is free text (not one of the old Rails enum values) — confirms Task 4's fix actually took effect in practice, not just in the schema file.
- No mention of `ce-compound-refresh`, `ce-compound`, or `/ce-compound` appears anywhere in the agent's summary or the written doc.
- If a `CONCEPTS.md` got bootstrapped, its preamble reads "compound-learnings processes new learnings" (Task 3 Step 5's fix), not the old text.

If any check fails, fix the relevant skill file and re-run Step 2.

- [ ] **Step 4: Clean up the scratch repo**

```bash
rm -rf /tmp/compound-learnings-test
```

---

## Task 13: Pressure-test `ideate`, including explicit tool-absence testing

Per the integration spec's Decision 6 note: `ideate`'s Slack/issue-tracker-dependent subagents must be verified to degrade gracefully when those tools are absent, not assumed to work from a copy alone. Also verifies the `brainstorming` handoff rewritten in Task 8 actually works end-to-end.

**Files:** none (this task produces no file changes unless testing surfaces a bug, in which case fix it and re-verify)

- [ ] **Step 1: Dispatch a subagent to invoke `ideate` with no Slack or issue-tracker MCP tools available**

Use the `Agent` tool with a prompt asking for ideas on some concrete, harmless topic (e.g. "ideas for improving the onboarding docs in this repo"), in an environment where no Slack or issue-tracker MCP tools are configured (the default for this environment — confirm via `ToolSearch` that no `mcp__slack__*` or issue-tracker tools resolve). Run in the foreground.

- [ ] **Step 2: Verify graceful degradation**

Check:
- The run completes and produces an ideation deliverable — it does not fail, hang, or hallucinate Slack/issue-tracker results.
- The agent's summary doesn't claim to have consulted Slack or an issue tracker.
- The `web-researcher` subagent dispatch either succeeds (WebSearch/WebFetch resolve) or is reported as unavailable — not silently skipped without mention.

- [ ] **Step 3: Verify the `brainstorming` handoff**

In the same or a follow-up session, once ideas are generated, choose the "Brainstorm one idea with `brainstorming`" option from the Phase 5 menu (Task 8's rewrite). Verify:
- The `brainstorming` skill actually gets invoked (not `ce-brainstorm`, which doesn't exist and would error or hallucinate).
- It receives a seed matching the format from Task 8 Step 3 (title, description, basis, rationale, tradeoffs, provenance pointer) — not the whole ideation file.
- `brainstorming` proceeds with its own normal dialogue from there.

If any check fails, fix the relevant skill file (most likely `post-ideation-workflow.md` or `universal-ideation.md`) and re-run.

---

## Task 14: Final verification pass and version bump

**Files:**
- Modify: `.claude-plugin/plugin.json` (version bump)
- Modify: `.claude-plugin/marketplace.json` (version bump)

- [ ] **Step 1: Full-repo grep for any surviving stale references in the two new skills**

Run: `grep -rn "ce-compound-refresh\|ce-simplify-code\|ce-brainstorm\|ce-proof\|gstack" skills/compound-learnings skills/ideate`
Expected: no output.

Run: `grep -rln "^import\|^from" skills/compound-learnings/scripts/*.py skills/compound-learnings/scripts/session-history/*.py | xargs grep -n "^import\|^from"`
Expected: same stdlib-only import list confirmed in Task 1 Step 3 — re-verify nothing changed.

- [ ] **Step 2: Verify both new skills' frontmatter is exactly two fields**

Run: `head -4 skills/compound-learnings/SKILL.md skills/ideate/SKILL.md`
Expected: each shows `---`, `name: ...`, `description: ...`, `---` — no `argument-hint`, no other keys.

- [ ] **Step 3: Bump the version**

Read `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` first, then bump the `version` field in both by one minor version (e.g. `6.1.1` → `6.2.0`) — new skills, no breaking changes. (`scripts/bump-version.sh`, which used to automate this across files, was removed in the personal-use cleanup pass — this is a manual two-file edit per the integration spec's Phase 3 note.)

- [ ] **Step 4: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "Bump version for compound-learnings and ideate skills"
```

---

## Self-Review

**1. Spec coverage** (against the integration spec's Phase 1 items):
- Copy `references/`/`scripts/` verbatim → Tasks 1, 6.
- Rewrite frontmatter to two fields, drop `argument-hint` → Tasks 2, 7.
- Cross-link `ideate` ↔ `brainstorming` and `compound-learnings` ↔ `writing-skills` → Tasks 5, 11.
- Pressure-test both, with `ideate` needing explicit subagent tool-absence testing → Tasks 12, 13.
- Additional fixes found during recon, not in the original spec: `ce-compound-refresh`/`ce-simplify-code` removal (Task 3), Rails-specific schema genericization (Task 4), `ce-brainstorm`/`ce-proof` remapping (Tasks 8, 9, 10). These are necessary for the ported skills to function at all outside compound-engineering's own plugin suite — the spec's Decision 6 ("port verbatim... no translation needed") turned out to be true only for the subagent-dispatch *mechanism*, not for these cross-skill *handoffs*.

**2. Placeholder scan:** no TBD/TODO markers; every step has literal before/after text or an exact command with expected output.

**3. Type/naming consistency:** `compound-learnings` and `ideate` are used consistently as the new names throughout; verified via the grep-verify steps in Tasks 3, 7, 8, 9, 10, 14 rather than by inspection alone.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-19-phase1-compound-learnings-and-ideate-plan.md`. Two execution options:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?