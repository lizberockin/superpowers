# Phase 2a: Port office-hours Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Port gstack's `office-hours` skill into `skills/office-hours/` as a standalone, dependency-free superpowers skill — preserving the YC-office-hours methodology (forcing questions, premise challenge, alternatives generation, design doc output) while stripping or translating everything that depends on gstack's private runtime.

**Architecture:** Copy the two source files verbatim, then strip ~800 lines of gstack's shared resolver-injected boilerplate, translate the sections that had a genuine portable equivalent (context-gathering onto the wiki, visuals onto `brainstorming`'s Visual Companion, cross-session personalization dropped outright), and leave the actual methodology (the forcing questions, premise challenge, alternatives generation, design-doc templates) untouched. Nothing here builds new infrastructure beyond a two-tier context step and reusing `brainstorming`'s existing companion.

**Tech Stack:** Markdown skill files, Bash, YAML frontmatter. This is a documentation/content migration, not application code — "tests" in this plan are grep-verification steps (confirm no stale gstack references remain) and a skill pressure-test via subagent dispatch (confirm an agent given the rewritten skill actually follows it correctly), not unit tests.

## Global Constraints

- Frontmatter on `office-hours/SKILL.md`: exactly two fields, `name` and `description`, `description` in third-person "Use when..." form. (Source: office-hours spec, Decision 3.)
- File layout is flat: `skills/office-hours/SKILL.md` + `skills/office-hours/design-and-handoff.md` — no `sections/` subfolder, no `manifest.json`. (Source: office-hours spec, Decision 2.)
- No references to `gstack`, `~/.gstack`, or any `gstack-*` CLI may survive the port anywhere in either file. (Source: office-hours spec, Pressure-testing plan.)
- The design doc this skill produces is written to `docs/superpowers/office-hours/`, never `docs/superpowers/specs/` (that directory stays exclusively brainstorming-approved specs). (Source: office-hours spec, Decision 5.)
- Hand-offs to `brainstorming` and to the future `plan-ceo-review`/`plan-eng-review` are **prose mentions only** — no active `Skill`-tool auto-invocation. The `plan-ceo-review`/`plan-eng-review` forward-references are **kept**, not stripped, even though those skills don't exist yet (Phase 2b lands immediately after this). (Source: office-hours spec, Decisions 4, 11, 12.)
- Any AI-image-generation or headless-browser-rendering dependency is dropped outright, with no substitute built for it beyond reusing `brainstorming`'s existing Visual Companion. (Source: office-hours spec, Decision 7.)
- Cross-session personalization (relationship tiering, developer-signal profile write-back) is dropped outright, no substitute. (Source: office-hours spec, Decisions 11, 13.)

---

## Task 1: Copy the source files into `skills/office-hours/`

**Files:**
- Create: `skills/office-hours/SKILL.md` (copy of `/Users/lizbrokken/AI/gstack/office-hours/SKILL.md`)
- Create: `skills/office-hours/design-and-handoff.md` (copy of `/Users/lizbrokken/AI/gstack/office-hours/sections/design-and-handoff.md`)

- [ ] **Step 1: Copy both files, flattening the section into the skill root**

```bash
mkdir -p skills/office-hours
cp /Users/lizbrokken/AI/gstack/office-hours/SKILL.md skills/office-hours/SKILL.md
cp /Users/lizbrokken/AI/gstack/office-hours/sections/design-and-handoff.md skills/office-hours/design-and-handoff.md
```

- [ ] **Step 2: Verify line counts match the source**

Run: `wc -l skills/office-hours/SKILL.md skills/office-hours/design-and-handoff.md`
Expected: `1697` and `584` respectively (matching the source files exactly — this is a raw copy, no edits yet).

- [ ] **Step 3: Commit the raw copy before any edits**

```bash
git add skills/office-hours
git commit -m "Copy gstack's office-hours into skills/office-hours (unmodified)

Raw copy, flattened from gstack's sections/design-and-handoff.md into
skills/office-hours/design-and-handoff.md. Subsequent commits rewrite
this in place per docs/superpowers/specs/2026-07-20-office-hours-port-design.md."
```

---

## Task 2: Rewrite frontmatter, fold in trigger content, add the `brainstorming` cross-link

Per office-hours spec Decisions 3, 4, and 12. This task replaces the frontmatter block and the old "When to invoke this skill" section (lines 1-64 of the source) with a two-field frontmatter and a short intro. It stops right before `## Preamble (run first)`, which Task 3 deletes — this task does not touch that block.

**Files:**
- Modify: `skills/office-hours/SKILL.md` (lines 1-64)

- [ ] **Step 1: Replace the frontmatter and "When to invoke this skill" section**

Old (lines 1-64):
```markdown
---
name: office-hours
preamble-tier: 3
version: 2.0.0
description: YC Office Hours — two modes. (gstack)
allowed-tools:
  - Bash
  - Read
  - Grep
  - Glob
  - Write
  - Edit
  - AskUserQuestion
  - WebSearch
triggers:
  - brainstorm this
  - is this worth building
  - help me think through
  - office hours
gbrain:
  schema: 1
  context_queries:
    - id: prior-sessions
      kind: list
      filter:
        type: ceo-plan
        tags_contains: "repo:{repo_slug}"
      sort: updated_at_desc
      limit: 5
      render_as: "## Prior office-hours sessions in this repo"
    - id: builder-profile
      kind: filesystem
      glob: "~/.gstack/builder-profile.jsonl"
      tail: 1
      render_as: "## Your builder profile snapshot"
    - id: design-doc-history
      kind: filesystem
      glob: "~/.gstack/projects/{repo_slug}/*-design-*.md"
      sort: mtime_desc
      limit: 3
      render_as: "## Recent design docs for this project"
    - id: prior-eureka
      kind: filesystem
      glob: "~/.gstack/analytics/eureka.jsonl"
      tail: 5
      render_as: "## Recent eureka moments"
---
<!-- AUTO-GENERATED from SKILL.md.tmpl — do not edit directly -->
<!-- Regenerate: bun run gen:skill-docs -->


## When to invoke this skill

Startup mode: six forcing questions that expose
demand reality, status quo, desperate specificity, narrowest wedge, observation,
and future-fit. Builder mode: design thinking brainstorming for side projects,
hackathons, learning, and open source. Saves a design doc.
Use when asked to "brainstorm this", "I have an idea", "help me think through
this", "office hours", or "is this worth building".
Proactively invoke this skill (do NOT answer directly) when the user describes
a new product idea, asks whether something is worth building, wants to think
through design decisions for something that doesn't exist yet, or is exploring
a concept before any code is written.
Use before /plan-ceo-review or /plan-eng-review.
```

New:
```markdown
---
name: office-hours
description: Use when the user has a new product/project idea, asks whether something is worth building, wants to think through design decisions for something that doesn't exist yet, or is exploring a concept before any code is written — proactively invoke rather than answering directly. Two modes: Startup mode runs six YC-style forcing questions (demand reality, status quo, desperate specificity, narrowest wedge, observation, future-fit); Builder mode is design-thinking brainstorming for side projects, hackathons, learning, and open source. Produces a design doc, never code.
---

**See also:** `superpowers:brainstorming` — office-hours decides *whether* an idea is worth building and does open-ended design brainstorming; `brainstorming` turns an idea you're already committed to into an approved, implementation-ready design. Run office-hours first when the idea's worth is still in question. Use before `plan-ceo-review`/`plan-eng-review` once those land (Phase 2b) to pressure-test scope and architecture on the resulting design doc.
```

- [ ] **Step 2: Verify the frontmatter is exactly two fields**

Run: `sed -n '/^---$/,/^---$/p' skills/office-hours/SKILL.md | head -5`
Expected:
```
---
name: office-hours
description: Use when the user has a new product/project idea...
---
```

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/SKILL.md
git commit -m "Rewrite office-hours frontmatter to two-field contract, fold trigger content into intro"
```

---

## Task 3: Delete the shared gstack runtime boilerplate block

Per office-hours spec's "Source file assessment": everything between `## Preamble (run first)` and the end of `## SETUP (run this check BEFORE any browse command)` is gstack's shared, resolver-injected runtime — identical in shape across every gstack skill, none of it skill-specific. This is a pure deletion; the file's actual skill content (`# YC Office Hours` heading and the HARD GATE paragraph) sits immediately *after* this block and is untouched by this task.

**Files:**
- Modify: `skills/office-hours/SKILL.md`

- [ ] **Step 1: Delete the boilerplate block**

Delete everything from the line containing `## Preamble (run first)` through the last line of the `## SETUP (run this check BEFORE any browse command)` section — i.e., every heading in this list and its content: `Preamble (run first)`, `Plan Mode Safe Operations`, `Skill Invocation During Plan Mode`, `First-run guidance (one-time)`, `Skill routing`, `AskUserQuestion Format`, `Artifacts Sync (skill start)`, `Model-Specific Behavioral Patch (claude)`, `Voice`, `Context Recovery`, `Writing Style (...)`, `Completeness Principle — Boil the Ocean`, `Confusion Protocol`, `Continuous Checkpoint Mode`, `Context Health (soft directive)`, `Question Tuning (...)`, `Repo Ownership — See Something, Say Something`, `Search Before Building`, `Completion Status Protocol`, `Operational Self-Improvement`, `Telemetry (run last)`, `Plan Status Footer`, `SETUP (run this check BEFORE any browse command)`.

Stop deleting immediately before the line `# YC Office Hours` — that heading and everything from it onward (the HARD GATE paragraph, then `## Brain Context (preflight)`) must survive.

- [ ] **Step 2: Verify the boilerplate headings are gone and the real content survived**

Run: `grep -n "^## \|^# " skills/office-hours/SKILL.md | head -5`
Expected: the first lines should now be `# YC Office Hours` followed shortly by `## Brain Context (preflight)` — none of the boilerplate headings listed in Step 1 should appear anywhere in the file.

Run: `grep -c "^## Preamble (run first)\|^## AskUserQuestion Format\|^## Voice$\|^## Telemetry (run last)" skills/office-hours/SKILL.md`
Expected: `0`

Run: `grep -n "^# YC Office Hours\|HARD GATE" skills/office-hours/SKILL.md`
Expected: both lines present, near the top of the file.

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/SKILL.md
git commit -m "Delete gstack's shared runtime boilerplate from office-hours (preamble through SETUP)

~800 lines of resolver-injected content identical across every gstack
skill — no skill-specific behavior lost. The skill's actual intro
(# YC Office Hours, HARD GATE) sat right after this block and survives."
```

---

## Task 4: Replace Brain Context + Prior Learnings with the two-tier context step

Per office-hours spec Decision 6. Merges three source sections (`Brain Context (preflight)`, `Phase 1: Context Gathering`, `Prior Learnings`) into one `Phase 1: Context Gathering` section. Items 5-6 of the original numbered list ("what's your goal", "assess product stage") are genuine methodology, not gstack infra — they're preserved verbatim as items 5-6 of the new list.

**Files:**
- Modify: `skills/office-hours/SKILL.md`

- [ ] **Step 1: Replace the three sections with one merged section**

Old (from `## Brain Context (preflight)` through the end of `## Prior Learnings`, i.e. everything up to but not including `## Section index`):
```markdown
## Brain Context (preflight)

Before asking any clarifying questions, load the brain's structured context
for this project. The cache layer handles staleness, refresh, and stale-but-
usable fallback automatically. Skip questions whose answers are already
present in the loaded context; ground recommendations in what the brain
already knows about the user, the product, the goals, and recent decisions.

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)" 2>/dev/null || true
{
  printf '## Brain Context\n\n'
  printf '\n### %s\n\n' "product"
  ~/.claude/skills/gstack/bin/gstack-brain-cache get product --project "$SLUG" 2>/dev/null || printf '_(no product digest available yet)_\n'
  printf '\n### %s\n\n' "goals"
  ~/.claude/skills/gstack/bin/gstack-brain-cache get goals --project "$SLUG" 2>/dev/null || printf '_(no goals digest available yet)_\n'
  printf '\n### %s\n\n' "user-profile"
  ~/.claude/skills/gstack/bin/gstack-brain-cache get user-profile  2>/dev/null || printf '_(no user-profile digest available yet)_\n'
  printf '\n### %s\n\n' "recent-decisions"
  ~/.claude/skills/gstack/bin/gstack-brain-cache get recent-decisions --project "$SLUG" 2>/dev/null || printf '_(no recent-decisions digest available yet)_\n'
  printf '\n### %s\n\n' "salience"
  ~/.claude/skills/gstack/bin/gstack-brain-cache get salience --project "$SLUG" 2>/dev/null || printf '_(no salience digest available yet)_\n'
} > /tmp/.gstack-brain-context-$$.md 2>/dev/null
[ -s /tmp/.gstack-brain-context-$$.md ] && cat /tmp/.gstack-brain-context-$$.md
rm -f /tmp/.gstack-brain-context-$$.md 2>/dev/null || true
```

**How to use this context:**
- If `product` digest names the value prop, target user, or stage — don't re-ask.
- If `goals` digest lists active goals — frame recommendations against them.
- If `recent-decisions` digest names a prior scope/architecture choice — flag if this plan contradicts.
- If `user-profile` digest carries calibration pattern statements ("tends to over-engineer security") — surface them when relevant.
- If a digest is `(no X digest available yet)`, treat that section as cold; ask the user.

**Privacy:** Salience digest is filtered by allowlist (D9 default: `projects/`,
`gstack/`, `concepts/` only). Personal/family/therapy content never leaks here.


## Phase 1: Context Gathering

Understand the project and the area the user wants to change.

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
```

1. Read `CLAUDE.md`, `TODOS.md` (if they exist).
2. Run `git log --oneline -30` and `git diff origin/main --stat 2>/dev/null` to understand recent context.
3. Use Grep/Glob to map the codebase areas most relevant to the user's request.
4. **List existing design docs for this project:**
   ```bash
   setopt +o nomatch 2>/dev/null || true  # zsh compat
   ls -t ~/.gstack/projects/$SLUG/*-design-*.md 2>/dev/null
   ```
   If design docs exist, list them: "Prior designs for this project: [titles + dates]"

## Prior Learnings

Search for relevant learnings from previous sessions:

```bash
_CROSS_PROJ=$(~/.claude/skills/gstack/bin/gstack-config get cross_project_learnings 2>/dev/null || echo "unset")
echo "CROSS_PROJECT: $_CROSS_PROJ"
if [ "$_CROSS_PROJ" = "true" ]; then
  ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10 --cross-project 2>/dev/null || true
else
  ~/.claude/skills/gstack/bin/gstack-learnings-search --limit 10 2>/dev/null || true
fi
```

If `CROSS_PROJECT` is `unset` (first time): Use AskUserQuestion:

> gstack can search learnings from your other projects on this machine to find
> patterns that might apply here. This stays local (no data leaves your machine).
> Recommended for solo developers. Skip if you work on multiple client codebases
> where cross-contamination would be a concern.

Options:
- A) Enable cross-project learnings (recommended)
- B) Keep learnings project-scoped only

If A: run `~/.claude/skills/gstack/bin/gstack-config set cross_project_learnings true`
If B: run `~/.claude/skills/gstack/bin/gstack-config set cross_project_learnings false`

Then re-run the search with the appropriate flag.

If learnings are found, incorporate them into your analysis. When a review finding
matches a past learning, display:

**"Prior learning applied: [key] (confidence N/10, from [date])"**

This makes the compounding visible. The user should see that gstack is getting
smarter on their codebase over time.

5. **Ask: what's your goal with this?** This is a real question, not a formality. The answer determines everything about how the session runs.

   Via AskUserQuestion, ask:

   > Before we dig in — what's your goal with this?
   >
   > - **Building a startup** (or thinking about it)
   > - **Intrapreneurship** — internal project at a company, need to ship fast
   > - **Hackathon / demo** — time-boxed, need to impress
   > - **Open source / research** — building for a community or exploring an idea
   > - **Learning** — teaching yourself to code, vibe coding, leveling up
   > - **Having fun** — side project, creative outlet, just vibing

   **Mode mapping:**
   - Startup, intrapreneurship → **Startup mode** (Phase 2A)
   - Hackathon, open source, research, learning, having fun → **Builder mode** (Phase 2B)

6. **Assess product stage** (only for startup/intrapreneurship modes):
   - Pre-product (idea stage, no users yet)
   - Has users (people using it, not yet paying)
   - Has paying customers

Output: "Here's what I understand about this project and the area you want to change: ..."
```

New:
```markdown
## Phase 1: Context Gathering

Understand the project and the area the user wants to change.

Before asking any clarifying questions, ground yourself in what's already known — skip questions whose answers are already on record.

**Wiki context (primary source):** search `docs/solutions/` and `CONCEPTS.md` for anything relevant to the area the user wants to change. If either doesn't exist yet, treat this as a cold project and move on — an empty wiki is a normal state, not an error.

**Fallback context:** if the wiki is empty or the repo hasn't adopted it, fall back to `docs/superpowers/specs/`, `docs/superpowers/plans/`, and `git log --oneline -20` for relevant prior context.

1. Read `CLAUDE.md`, `TODOS.md` (if they exist).
2. Run `git log --oneline -30` and `git diff origin/main --stat 2>/dev/null` to understand recent context.
3. Use Grep/Glob to map the codebase areas most relevant to the user's request.
4. **List prior office-hours sessions for this project:**
   ```bash
   ls -t docs/superpowers/office-hours/*.md 2>/dev/null
   ```
   If prior sessions exist, list them: "Prior office-hours sessions for this project: [titles + dates]"
5. **Ask: what's your goal with this?** This is a real question, not a formality. The answer determines everything about how the session runs.

   Via AskUserQuestion, ask:

   > Before we dig in — what's your goal with this?
   >
   > - **Building a startup** (or thinking about it)
   > - **Intrapreneurship** — internal project at a company, need to ship fast
   > - **Hackathon / demo** — time-boxed, need to impress
   > - **Open source / research** — building for a community or exploring an idea
   > - **Learning** — teaching yourself to code, vibe coding, leveling up
   > - **Having fun** — side project, creative outlet, just vibing

   **Mode mapping:**
   - Startup, intrapreneurship → **Startup mode** (Phase 2A)
   - Hackathon, open source, research, learning, having fun → **Builder mode** (Phase 2B)

6. **Assess product stage** (only for startup/intrapreneurship modes):
   - Pre-product (idea stage, no users yet)
   - Has users (people using it, not yet paying)
   - Has paying customers

If wiki or fallback context surfaced anything relevant, incorporate it into your analysis and say so: "Prior context found: [1-line summary]. Grounding this session in it."

Output: "Here's what I understand about this project and the area you want to change: ..."
```

- [ ] **Step 2: Verify the merge**

Run: `grep -n "^## Brain Context\|^## Prior Learnings\|gstack-brain-cache\|gstack-learnings-search\|cross_project_learnings" skills/office-hours/SKILL.md`
Expected: no output.

Run: `grep -n "^## Phase 1: Context Gathering" skills/office-hours/SKILL.md`
Expected: exactly one match.

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/SKILL.md
git commit -m "Replace office-hours' Brain Context + Prior Learnings with the wiki-then-specs/git-log context step

Merges three source sections into one Phase 1: Context Gathering.
The goal-question and product-stage-assessment items (5-6) are real
methodology and are preserved verbatim, not just the gstack infra
around them removed."
```

---

## Task 5: Translate Phase 2.5 Related Design Discovery

Per office-hours spec Decision 6 (second half). This is a separate, later section from Task 4's merge — it's about *office-hours' own prior sessions* on this specific topic (keyword-matched), not the general project wiki.

**Files:**
- Modify: `skills/office-hours/SKILL.md`

- [ ] **Step 1: Replace the section**

Old:
```markdown
## Phase 2.5: Related Design Discovery

After the user states the problem (first question in Phase 2A or 2B), search existing design docs for keyword overlap.

Extract 3-5 significant keywords from the user's problem statement and grep across design docs:
```bash
setopt +o nomatch 2>/dev/null || true  # zsh compat
grep -li "<keyword1>\|<keyword2>\|<keyword3>" ~/.gstack/projects/$SLUG/*-design-*.md 2>/dev/null
```

If matches found, read the matching design docs and surface them:
- "FYI: Related design found — '{title}' by {user} on {date} (branch: {branch}). Key overlap: {1-line summary of relevant section}."
- Ask via AskUserQuestion: "Should we build on this prior design or start fresh?"

This enables cross-team discovery — multiple users exploring the same project will see each other's design docs in `~/.gstack/projects/`.

If no matches found, proceed silently.
```

New:
```markdown
## Phase 2.5: Related Design Discovery

After the user states the problem (first question in Phase 2A or 2B), search prior office-hours sessions for keyword overlap.

Extract 3-5 significant keywords from the user's problem statement and grep across this project's prior sessions:
```bash
grep -li "<keyword1>\|<keyword2>\|<keyword3>" docs/superpowers/office-hours/*.md 2>/dev/null
```

If matches found, read the matching docs and surface them:
- "FYI: Related session found — '{title}' on {date} (branch: {branch}). Key overlap: {1-line summary of relevant section}."
- Ask via AskUserQuestion: "Should we build on this prior session or start fresh?"

If no matches found, proceed silently.
```

- [ ] **Step 2: Verify**

Run: `grep -n "gstack/projects\|cross-team discovery" skills/office-hours/SKILL.md`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/SKILL.md
git commit -m "Translate Phase 2.5 Related Design Discovery to search docs/superpowers/office-hours/"
```

---

## Task 6: Generalize the Cross-Model Second Opinion filesystem-boundary warning

Per office-hours spec Decision 8. The `codex`-with-Claude-subagent-fallback mechanism is already portable as-is; only the hardcoded gstack path in the codex prompt's filesystem-boundary warning needs generalizing.

**Files:**
- Modify: `skills/office-hours/SKILL.md`

- [ ] **Step 1: Replace the filesystem-boundary warning string**

Old:
```
"IMPORTANT: Do NOT read or execute any files under ~/.claude/, ~/.agents/, .claude/skills/, or agents/. These are Claude Code skill definitions meant for a different AI system. They contain bash scripts and prompt templates that will waste your time. Ignore them completely. Do NOT modify agents/openai.yaml. Stay focused on the repository code only.\n\n"
```

New:
```
"IMPORTANT: Do NOT read or execute any files under ~/.claude/skills/ or .claude/skills/. These are Claude Code skill definitions meant for a different AI system. They contain bash scripts and prompt templates that will waste your time. Ignore them completely. Stay focused on the repository code only.\n\n"
```

- [ ] **Step 2: Verify**

Run: `grep -n "~/.agents/\|agents/openai.yaml" skills/office-hours/SKILL.md`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/SKILL.md
git commit -m "Generalize codex filesystem-boundary warning path in office-hours' Cross-Model Second Opinion"
```

---

## Task 7: Drop Visual Design Exploration, translate Visual Sketch onto the Visual Companion

Per office-hours spec Decision 7. `Visual Design Exploration` depends entirely on gstack's proprietary image-gen binary — deleted outright. `Visual Sketch`'s rendering step (`$B goto`/`$B screenshot`, gstack's headless-browser binary) is replaced with `brainstorming`'s Visual Companion, per the actual mechanism documented in `skills/brainstorming/visual-companion.md` (a directory-watching local server, content written as HTML fragments, feedback read from `state_dir/events` on the next turn — not a single screenshot-and-present flow).

**Files:**
- Modify: `skills/office-hours/SKILL.md`

- [ ] **Step 1: Delete `## Visual Design Exploration` entirely and rewrite `## Visual Sketch`**

Old (from `## Visual Design Exploration` through the end of `## Visual Sketch (UI ideas only)`):
```markdown
## Visual Design Exploration

```bash
_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
D=""
[ -n "$_ROOT" ] && [ -x "$_ROOT/.claude/skills/gstack/design/dist/design" ] && D="$_ROOT/.claude/skills/gstack/design/dist/design"
[ -z "$D" ] && D="$HOME/.claude/skills/gstack/design/dist/design"
[ -x "$D" ] && echo "DESIGN_READY" || echo "DESIGN_NOT_AVAILABLE"
```

**If `DESIGN_NOT_AVAILABLE`:** Fall back to the HTML wireframe approach below
(the existing DESIGN_SKETCH section). Visual mockups require the design binary.

**If `DESIGN_READY`:** Generate visual mockup explorations for the user.

Generating visual mockups of the proposed design... (say "skip" if you don't need visuals)

**Step 1: Set up the design directory**

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)"
_DESIGN_DIR="$HOME/.gstack/projects/$SLUG/designs/mockup-$(date +%Y%m%d)"
mkdir -p "$_DESIGN_DIR"
echo "DESIGN_DIR: $_DESIGN_DIR"
```

**Step 2: Construct the design brief**

Read DESIGN.md if it exists — use it to constrain the visual style. If no DESIGN.md,
explore wide across diverse directions.

**Step 3: Generate 3 variants**

```bash
$D variants --brief "<assembled brief>" --count 3 --output-dir "$_DESIGN_DIR/"
```

This generates 3 style variations of the same brief (~40 seconds total).

**Step 4: Show variants inline, then open comparison board**

Show each variant to the user inline first (read the PNGs with Read tool), then
create and serve the comparison board:

```bash
$D compare --images "$_DESIGN_DIR/variant-A.png,$_DESIGN_DIR/variant-B.png,$_DESIGN_DIR/variant-C.png" --output "$_DESIGN_DIR/design-board.html" --serve
```

This opens the board in the user's default browser and blocks until feedback is
received. Read stdout for the structured JSON result. No polling needed.

If `$D serve` is not available or fails, fall back to AskUserQuestion:
"I've opened the design board. Which variant do you prefer? Any feedback?"

**Step 5: Handle feedback**

If the JSON contains `"regenerated": true`:
1. Read `regenerateAction` (or `remixSpec` for remix requests)
2. Generate new variants with `$D iterate` or `$D variants` using updated brief
3. Create new board with `$D compare`
4. POST the new HTML to the running board. Parse the board URL from stderr
   (`BOARD_URL: http://127.0.0.1:N/boards/<id>/` — the daemon path) or fall
   back to the legacy port (`SERVE_STARTED: port=N` — only emitted under
   `--no-daemon`, hits `/api/reload` root). Daemon path:
   `curl -X POST "${BOARD_URL}api/reload" -H 'Content-Type: application/json' -d '{"html":"$_DESIGN_DIR/design-board.html"}'`
5. Board auto-refreshes in the same tab

If `"regenerated": false`: proceed with the approved variant.

**Step 6: Save approved choice**

```bash
echo '{"approved_variant":"<VARIANT>","feedback":"<FEEDBACK>","date":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","screen":"mockup","branch":"'$(git branch --show-current 2>/dev/null)'"}' > "$_DESIGN_DIR/approved.json"
```

Reference the saved mockup in the design doc or plan.

## Visual Sketch (UI ideas only)

If the chosen approach involves user-facing UI (screens, pages, forms, dashboards,
or interactive elements), generate a rough wireframe to help the user visualize it.
If the idea is backend-only, infrastructure, or has no UI component — skip this
section silently.

**Step 1: Gather design context**

1. Check if `DESIGN.md` exists in the repo root. If it does, read it for design
   system constraints (colors, typography, spacing, component patterns). Use these
   constraints in the wireframe.
2. Apply core design principles:
   - **Information hierarchy** — what does the user see first, second, third?
   - **Interaction states** — loading, empty, error, success, partial
   - **Edge case paranoia** — what if the name is 47 chars? Zero results? Network fails?
   - **Subtraction default** — "as little design as possible" (Rams). Every element earns its pixels.
   - **Design for trust** — every interface element builds or erodes user trust.

**Step 2: Generate wireframe HTML**

Generate a single-page HTML file with these constraints:
- **Intentionally rough aesthetic** — use system fonts, thin gray borders, no color,
  hand-drawn-style elements. This is a sketch, not a polished mockup.
- Self-contained — no external dependencies, no CDN links, inline CSS only
- Show the core interaction flow (1-3 screens/states max)
- Include realistic placeholder content (not "Lorem ipsum" — use content that
  matches the actual use case)
- Add HTML comments explaining design decisions

Write to a temp file:
```bash
SKETCH_FILE="/tmp/gstack-sketch-$(date +%s).html"
```

**Step 3: Render and capture**

```bash
$B goto "file://$SKETCH_FILE"
$B screenshot /tmp/gstack-sketch.png
```

If `$B` is not available (browse binary not set up), skip the render step. Tell the
user: "Visual sketch requires the browse binary. Run the setup script to enable it."

**Step 4: Present and iterate**

Show the screenshot to the user. Ask: "Does this feel right? Want to iterate on the layout?"

If they want changes, regenerate the HTML with their feedback and re-render.
If they approve or say "good enough," proceed.

**Step 5: Include in design doc**

Reference the wireframe screenshot in the design doc's "Recommended Approach" section.
The screenshot file at `/tmp/gstack-sketch.png` can be referenced by downstream skills
(`/plan-design-review`, `/design-review`) to see what was originally envisioned.

**Step 6: Outside design voices** (optional)

After the wireframe is approved, offer outside design perspectives:

```bash
command -v codex >/dev/null 2>&1 && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
```

If Codex is available, use AskUserQuestion:
> "Want outside design perspectives on the chosen approach? Codex proposes a visual thesis, content plan, and interaction ideas. A Claude subagent proposes an alternative aesthetic direction."
>
> A) Yes — get outside design voices
> B) No — proceed without

If user chooses A, launch both voices simultaneously:

1. **Codex** (via Bash, `model_reasoning_effort="medium"`):
```bash
TMPERR_SKETCH=$(mktemp /tmp/codex-sketch-XXXXXXXX)
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
codex exec "For this product approach, provide: a visual thesis (one sentence — mood, material, energy), a content plan (hero → support → detail → CTA), and 2 interaction ideas that change page feel. Apply beautiful defaults: composition-first, brand-first, cardless, poster not document. Be opinionated." -C "$_REPO_ROOT" -s read-only -c 'model_reasoning_effort="medium"' --enable web_search_cached < /dev/null 2>"$TMPERR_SKETCH"
```
Use a 5-minute timeout (`timeout: 300000`). After completion: `cat "$TMPERR_SKETCH" && rm -f "$TMPERR_SKETCH"`

2. **Claude subagent** (via Agent tool):
"For this product approach, what design direction would you recommend? What aesthetic, typography, and interaction patterns fit? What would make this approach feel inevitable to the user? Be specific — font names, hex colors, spacing values."

Present Codex output under `CODEX SAYS (design sketch):` and subagent output under `CLAUDE SUBAGENT (design direction):`.
Error handling: all non-blocking. On failure, skip and continue.
```

New:
```markdown
## Visual Sketch (UI ideas only)

If the chosen approach involves user-facing UI (screens, pages, forms, dashboards,
or interactive elements), generate a rough wireframe to help the user visualize it.
If the idea is backend-only, infrastructure, or has no UI component — skip this
section silently.

**Step 1: Gather design context**

1. Check if `DESIGN.md` exists in the repo root. If it does, read it for design
   system constraints (colors, typography, spacing, component patterns). Use these
   constraints in the wireframe.
2. Apply core design principles:
   - **Information hierarchy** — what does the user see first, second, third?
   - **Interaction states** — loading, empty, error, success, partial
   - **Edge case paranoia** — what if the name is 47 chars? Zero results? Network fails?
   - **Subtraction default** — "as little design as possible" (Rams). Every element earns its pixels.
   - **Design for trust** — every interface element builds or erodes user trust.

**Step 2: Generate wireframe HTML**

Generate the wireframe as an HTML **content fragment** (not a full document — see
`skills/brainstorming/visual-companion.md`'s "Writing Content Fragments") with these
constraints:
- **Intentionally rough aesthetic** — use the companion's `.mock-nav`, `.mock-sidebar`,
  `.mock-content`, `.mock-button`, `.mock-input`, `.placeholder` classes (documented
  in the companion guide) rather than a polished custom design. This is a sketch.
- Show the core interaction flow (1-3 screens/states max)
- Include realistic placeholder content (not "Lorem ipsum" — use content that
  matches the actual use case)

**Step 3: Show it via the Visual Companion**

This wireframe is exactly the kind of content the Visual Companion exists for.
Offer it the same way `brainstorming` does — just-in-time, its own message, not
upfront (skip the offer if the user already accepted the companion earlier in
this session):

> "This next part might be easier if I show you — I can put the wireframe in a
> browser tab so you can see it directly. Want me to? I'll open it for you."

If declined, describe the wireframe in prose instead (layout, hierarchy, key
states) and skip to Step 5.

If accepted, follow `skills/brainstorming/visual-companion.md`:
1. Start the companion server if it isn't already running this session:
   `scripts/start-server.sh --project-dir <repo root> --open` (script lives
   under `skills/brainstorming/`).
2. Write the Step 2 wireframe fragment to a new file in the returned
   `screen_dir`, e.g. `wireframe.html`.
3. Tell the user the URL and a one-line summary of what's on screen, then end
   your turn.

**Step 4: Present and iterate**

On your next turn, read `$STATE_DIR/events` (if present) alongside the user's
terminal reply. Ask: "Does this feel right? Want to iterate on the layout?"

If they want changes, write a new versioned file (`wireframe-v2.html`, etc.) —
never overwrite an existing screen. If they approve or say "good enough," push
a brief waiting screen (per the companion guide's "Unload when returning to
terminal") and proceed.

**Step 5: Include in design doc**

Reference the wireframe in the design doc's "Recommended Approach" section so
downstream review work can see what was originally envisioned.

**Step 6: Outside design voices** (optional)

After the wireframe is approved, offer outside design perspectives:

```bash
command -v codex >/dev/null 2>&1 && echo "CODEX_AVAILABLE" || echo "CODEX_NOT_AVAILABLE"
```

If Codex is available, use AskUserQuestion:
> "Want outside design perspectives on the chosen approach? Codex proposes a visual thesis, content plan, and interaction ideas. A Claude subagent proposes an alternative aesthetic direction."
>
> A) Yes — get outside design voices
> B) No — proceed without

If user chooses A, launch both voices simultaneously:

1. **Codex** (via Bash, `model_reasoning_effort="medium"`):
```bash
TMPERR_SKETCH=$(mktemp /tmp/codex-sketch-XXXXXXXX)
_REPO_ROOT=$(git rev-parse --show-toplevel) || { echo "ERROR: not in a git repo" >&2; exit 1; }
codex exec "For this product approach, provide: a visual thesis (one sentence — mood, material, energy), a content plan (hero → support → detail → CTA), and 2 interaction ideas that change page feel. Apply beautiful defaults: composition-first, brand-first, cardless, poster not document. Be opinionated." -C "$_REPO_ROOT" -s read-only -c 'model_reasoning_effort="medium"' --enable web_search_cached < /dev/null 2>"$TMPERR_SKETCH"
```
Use a 5-minute timeout (`timeout: 300000`). After completion: `cat "$TMPERR_SKETCH" && rm -f "$TMPERR_SKETCH"`

2. **Claude subagent** (via Agent tool):
"For this product approach, what design direction would you recommend? What aesthetic, typography, and interaction patterns fit? What would make this approach feel inevitable to the user? Be specific — font names, hex colors, spacing values."

Present Codex output under `CODEX SAYS (design sketch):` and subagent output under `CLAUDE SUBAGENT (design direction):`.
Error handling: all non-blocking. On failure, skip and continue.
```

- [ ] **Step 2: Verify**

Run: `grep -n "gstack/design/dist\|\$D variants\|\$D compare\|gstack-sketch\|\\\$B goto\|\\\$B screenshot\|plan-design-review\|/design-review" skills/office-hours/SKILL.md`
Expected: no output.

Run: `grep -n "Visual Design Exploration" skills/office-hours/SKILL.md`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/SKILL.md
git commit -m "Drop office-hours' AI-mockup-variants step, translate wireframe rendering to brainstorming's Visual Companion

Visual Design Exploration depended on gstack's proprietary image-gen
binary with no portable substitute — dropped outright. Visual Sketch's
rendering mechanism (gstack's headless-browser binary) is replaced
with the same directory-watching companion server brainstorming
already has, rather than building a second visual-rendering path."
```

---

## Task 8: Clean up remaining gstack references (Capture Learnings, Eureka, Founder Signal write-back, stale paths)

Per office-hours spec Decisions 10, 13, 14, and 2. Several small, independent fixes in the tail of the file — bundled into one task since each is a few lines and they're all verified by the same final grep.

**Files:**
- Modify: `skills/office-hours/SKILL.md`

- [ ] **Step 1: Fix the Phase 2.75 eureka-logging line**

Old: `**Eureka check:** If Layer 3 reasoning reveals a genuine insight, name it: "EUREKA: Everyone does X because they assume [assumption]. But [evidence from our conversation] suggests that's wrong here. This means [implication]." Log the eureka moment (see preamble).`

New: `**Eureka check:** If Layer 3 reasoning reveals a genuine insight, name it: "EUREKA: Everyone does X because they assume [assumption]. But [evidence from our conversation] suggests that's wrong here. This means [implication]." Treat this as a candidate for \`compound-learnings\` at session end (see Capture Learnings).`

- [ ] **Step 2: Drop the Founder Signal Synthesis write-back subsection**

Old:
```markdown
Count the signals. You'll use this count in Phase 6 to determine which tier of closing message to use.

### Builder Profile Append

After counting signals, append a session entry to the builder profile. This is the single
source of truth for all closing state (tier, resource dedup, journey tracking). The
`gstack-developer-profile --log-session` binary handles its own directory creation
and writes via atomic mktemp+mv to `~/.gstack/developer-profile.json`.

Append one JSON line with these fields (substitute actual values from this session):
- `date`: current ISO 8601 timestamp
- `mode`: "startup" or "builder" (from Phase 1 mode selection)
- `project_slug`: the SLUG value from the preamble
- `signal_count`: number of signals counted above
- `signals`: array of signal names observed (e.g., `["named_users", "pushback", "taste"]`)
- `design_doc`: path to the design doc that will be written in Phase 5 (construct it now)
- `assignment`: the assignment you will give in the design doc's "The Assignment" section
- `resources_shown`: empty array `[]` for now (populated after resource selection in Phase 6)
- `topics`: array of 2-3 topic keywords that describe what this session was about

```bash
~/.claude/skills/gstack/bin/gstack-developer-profile --log-session '{"date":"TIMESTAMP","mode":"MODE","project_slug":"SLUG","signal_count":N,"signals":SIGNALS_ARRAY,"design_doc":"DOC_PATH","assignment":"ASSIGNMENT_TEXT","resources_shown":[],"topics":TOPICS_ARRAY}' 2>/dev/null || true
```

The session entry is appended to `developer-profile.json`'s `sessions[]` array. A second
session entry with `mode: "resources"` is appended via `--log-session` after resource
selection in Phase 6 Beat 3.5.
```

New:
```markdown
Count the signals. These feed the design doc's "What I noticed about how you think" section (Phase 5).
```

- [ ] **Step 3: Fix the STOP gate's path reference**

Old:
```
> **STOP.** Before writing the design doc and running the tiered relationship handoff (Phases 5-6, after the conversation and alternatives are done), Read `~/.claude/skills/gstack/office-hours/sections/design-and-handoff.md` and execute it
> in full. Do not work from memory — that section is the source of truth for this step.
```

New:
```
> **STOP.** Before writing the design doc and handoff (Phases 5-6, after the conversation and alternatives are done), Read `design-and-handoff.md` and execute it
> in full. Do not work from memory — that file is the source of truth for this step.
```

- [ ] **Step 4: Fix the Section index table row**

Old: `| writing the design doc and running the tiered relationship handoff (Phases 5-6, after the conversation and alternatives are done) | \`sections/design-and-handoff.md\` |`

New: `| writing the design doc and handoff (Phases 5-6, after the conversation and alternatives are done) | \`design-and-handoff.md\` |`

- [ ] **Step 5: Fix the Section self-check paragraph**

Old: `Confirm you Read every section the Section index named as applying to this run, and executed it in full. The design doc and the handoff are the deliverables — if you produced them from memory without Reading \`sections/design-and-handoff.md\`, stop and Read it now.`

New: `Confirm you Read every section the Section index named as applying to this run, and executed it in full. The design doc and the handoff are the deliverables — if you produced them from memory without Reading \`design-and-handoff.md\`, stop and Read it now.`

- [ ] **Step 6: Replace the Capture Learnings section**

Old:
```markdown
## Capture Learnings

If you discovered a non-obvious pattern, pitfall, or architectural insight during
this session, log it for future sessions:

```bash
~/.claude/skills/gstack/bin/gstack-learnings-log '{"skill":"office-hours","type":"TYPE","key":"SHORT_KEY","insight":"DESCRIPTION","confidence":N,"source":"SOURCE","files":["path/to/relevant/file"]}'
```

**Types:** `pattern` (reusable approach), `pitfall` (what NOT to do), `preference`
(user stated), `architecture` (structural decision), `tool` (library/framework insight),
`operational` (project environment/CLI/workflow knowledge).

**Sources:** `observed` (you found this in the code), `user-stated` (user told you),
`inferred` (AI deduction), `cross-model` (both Claude and Codex agree).

**Confidence:** 1-10. Be honest. An observed pattern you verified in the code is 8-9.
An inference you're not sure about is 4-5. A user preference they explicitly stated is 10.

**files:** Include the specific file paths this learning references. This enables
staleness detection: if those files are later deleted, the learning can be flagged.

**Only log genuine discoveries.** Don't log obvious things. Don't log things the user
already knows. A good test: would this insight save time in a future session? If yes, log it.
```

New:
```markdown
## Capture Learnings

If you discovered a non-obvious pattern, pitfall, or architectural insight during
this session, name it to the user as a candidate for `compound-learnings`:

"This session surfaced a reusable insight: {one-line description}. Worth capturing
with `compound-learnings` so it's not re-discovered next time."

**Only flag genuine discoveries.** Don't flag obvious things. Don't flag things the
user already knows. A good test: would this insight save time in a future session?
If yes, flag it.

This is a naming step, not a write — `compound-learnings` does the actual
documentation if the user acts on the suggestion.
```

- [ ] **Step 7: Verify no gstack references remain anywhere in the file**

Run: `grep -in "gstack" skills/office-hours/SKILL.md`
Expected: no output.

- [ ] **Step 8: Commit**

```bash
git add skills/office-hours/SKILL.md
git commit -m "Clean up remaining office-hours gstack references: eureka pointer, founder-signal write-back, stale paths, learning capture

Drops the second, separate developer-profile write-back inside
Founder Signal Synthesis (distinct from the Phase 6 tiering already
addressed elsewhere). Capture Learnings and the eureka check now
point at compound-learnings instead of calling a CLI that doesn't
exist here."
```

---

## Task 9: Rewrite `design-and-handoff.md` Phase 5 save path

Per office-hours spec Decision 5. The topic-slug convention matches how `brainstorming` names its own spec files — the agent derives a short kebab-case slug from the session's subject.

**Files:**
- Modify: `skills/office-hours/design-and-handoff.md`

- [ ] **Step 1: Replace the Phase 5 preamble and save-path instructions**

Old (lines 1-23):
```markdown
<!-- AUTO-GENERATED from design-and-handoff.md.tmpl — do not edit directly -->
<!-- Regenerate: bun run gen:skill-docs -->
## Phase 5: Design Doc

Write the design document to the project directory.

```bash
eval "$(~/.claude/skills/gstack/bin/gstack-slug 2>/dev/null)" && mkdir -p ~/.gstack/projects/$SLUG
USER=$(whoami)
DATETIME=$(date +%Y%m%d-%H%M%S)
```

**Design lineage:** Before writing, check for existing design docs on this branch:
```bash
setopt +o nomatch 2>/dev/null || true  # zsh compat
PRIOR=$(ls -t ~/.gstack/projects/$SLUG/*-$BRANCH-design-*.md 2>/dev/null | head -1)
```
If `$PRIOR` exists, the new doc gets a `Supersedes:` field referencing it. This creates a revision chain — you can trace how a design evolved across office hours sessions.

Write to `~/.gstack/projects/{slug}/{user}-{branch}-design-{datetime}.md`.

After writing the design doc, tell the user:
**"Design doc saved to: {full path}. Other skills (/plan-ceo-review, /plan-eng-review) will find it automatically."**
```

New:
```markdown
## Phase 5: Design Doc

Write the design document into the repo.

```bash
mkdir -p docs/superpowers/office-hours
BRANCH=$(git branch --show-current 2>/dev/null || echo 'no-branch')
DATE=$(date +%Y-%m-%d)
```

Choose a short kebab-case topic slug for this session (e.g. `todo-app`,
`auth-redesign`) — same convention `brainstorming` uses for its own spec
filenames.

**Design lineage:** Before writing, check for an existing office-hours doc on
this branch (match on the doc's `Branch:` header field, not the filename):
```bash
PRIOR=$(grep -l "^Branch: $BRANCH$" docs/superpowers/office-hours/*.md 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
```
If `$PRIOR` exists, the new doc gets a `Supersedes:` field referencing it. This creates a revision chain — you can trace how a design evolved across office hours sessions.

Write to `docs/superpowers/office-hours/{date}-{topic-slug}-office-hours.md`.

After writing the design doc, tell the user:
**"Design doc saved to: {full path}. A future `plan-ceo-review` or `plan-eng-review` will find it automatically."**
```

- [ ] **Step 2: Verify**

Run: `grep -n "gstack" skills/office-hours/design-and-handoff.md | head -5`
Expected: several remaining hits further down the file — that's expected, later tasks in this plan clean those up. This step just confirms Phase 5's own block no longer has any.

Run: `sed -n '1,25p' skills/office-hours/design-and-handoff.md | grep -n "gstack"`
Expected: no output.

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/design-and-handoff.md
git commit -m "Rewrite office-hours' design-doc save path to docs/superpowers/office-hours/

Lineage detection now matches on the doc's Branch: header field
instead of embedding branch in the filename, so the filename can
follow brainstorming's date+topic-slug convention exactly."
```

---

## Task 10: Drop the metrics-append step and the Brain Calibration / Cache Refresh sections

Per office-hours spec Decisions 9 and 13.

**Files:**
- Modify: `skills/office-hours/design-and-handoff.md`

- [ ] **Step 1: Drop the Spec Review Loop's metrics-append step**

Old:
```markdown
**Step 3: Report and persist metrics**

After the loop completes (PASS, max iterations, or convergence guard):

1. Tell the user the result — summary by default:
   "Your doc survived N rounds of adversarial review. M issues caught and fixed.
   Quality score: X/10."
   If they ask "what did the reviewer find?", show the full reviewer output.

2. If issues remain after max iterations or convergence, add a "## Reviewer Concerns"
   section to the document listing each unresolved issue. Downstream skills will see this.

3. Append metrics:
```bash
mkdir -p ~/.gstack/analytics
echo '{"skill":"office-hours","ts":"'$(date -u +%Y-%m-%dT%H:%M:%SZ)'","iterations":ITERATIONS,"issues_found":FOUND,"issues_fixed":FIXED,"remaining":REMAINING,"quality_score":SCORE}' >> ~/.gstack/analytics/spec-review.jsonl 2>/dev/null || true
```
Replace ITERATIONS, FOUND, FIXED, REMAINING, SCORE with actual values from the review.
```

New:
```markdown
**Step 3: Report the result**

After the loop completes (PASS, max iterations, or convergence guard):

1. Tell the user the result — summary by default:
   "Your doc survived N rounds of adversarial review. M issues caught and fixed.
   Quality score: X/10."
   If they ask "what did the reviewer find?", show the full reviewer output.

2. If issues remain after max iterations or convergence, add a "## Reviewer Concerns"
   section to the document listing each unresolved issue. Downstream skills will see this.
```

- [ ] **Step 2: Delete `Brain Calibration Write-Back` and `Brain Cache Background Refresh` entirely**

Delete everything from the line `## Brain Calibration Write-Back (Phase 2 / gated)` through the last line of `## Brain Cache Background Refresh` (both full sections, including their bash blocks) — stop immediately before `## Phase 6: Handoff — The Relationship Closing`, which Task 11 handles.

- [ ] **Step 3: Verify**

Run: `grep -n "gstack/analytics\|Brain Calibration\|Brain Cache Background\|gbrain\|takes_add" skills/office-hours/design-and-handoff.md`
Expected: no output.

- [ ] **Step 4: Commit**

```bash
git add skills/office-hours/design-and-handoff.md
git commit -m "Drop office-hours' spec-review metrics logging and Brain Calibration/Cache Refresh sections

Both are gbrain-specific with no superpowers equivalent and no
plausible lightweight substitute, per office-hours spec Decision 13."
```

---

## Task 11: Replace Phase 6 Handoff with a single prose line

Per office-hours spec Decisions 11 and 12. This is the file's largest single change — 315 of 584 lines collapse to a few lines. `Phase 6: Handoff — The Relationship Closing` is the last section in the file, so this deletion runs to end-of-file.

**Files:**
- Modify: `skills/office-hours/design-and-handoff.md`

- [ ] **Step 1: Replace everything from `## Phase 6: Handoff` to the end of the file**

Delete from the line `## Phase 6: Handoff — The Relationship Closing` through the last line of the file (the tiered relationship-closing system: Builder Profile read, the four tier blocks `introduction`/`welcome_back`/`regular`/`inner_circle`, Founder Resources, and the AskUserQuestion-driven next-skill auto-launch).

Replace with:
```markdown
## Phase 6: Handoff

Once the design doc is APPROVED, close the session.

Tell the user:

"Design doc saved to: {path}. Next: invoke `brainstorming` to turn this into an
implementation-ready design, or `plan-ceo-review`/`plan-eng-review` once
available to pressure-test scope and architecture first."

If a genuine, reusable discovery surfaced during this session (per Capture
Learnings in `SKILL.md`), mention it here too as a closing note, pointing at
`compound-learnings`.

Do not auto-launch the next skill. The user decides when to continue.
```

- [ ] **Step 2: Verify**

Run: `grep -n "builder-profile\|introduction\|welcome_back\|inner_circle\|gstack-telemetry-log\|handoff.*accepted\|handoff.*declined" skills/office-hours/design-and-handoff.md`
Expected: no output.

Run: `tail -15 skills/office-hours/design-and-handoff.md`
Expected: ends with the new Phase 6 content from Step 1 above.

- [ ] **Step 3: Commit**

```bash
git add skills/office-hours/design-and-handoff.md
git commit -m "Replace office-hours' Phase 6 relationship-tiering handoff with a single prose next-step line

Drops the cross-session builder-profile.jsonl-keyed tiering system
(introduction/welcome_back/regular/inner_circle) — genuinely
gstack-specific, ruled not recoverable in the umbrella integration
spec's Decision 4. What survives is a plain, non-auto-launching
next-step message per office-hours spec Decisions 11-12."
```

---

## Task 12: Full-file verification pass on both files

**Files:** none (verification only; fix and re-verify if anything surfaces)

- [ ] **Step 1: Grep both files for any surviving gstack references**

Run: `grep -in "gstack" skills/office-hours/SKILL.md skills/office-hours/design-and-handoff.md`
Expected: no output.

- [ ] **Step 2: Grep for stale `sections/` path references**

Run: `grep -n "sections/design-and-handoff" skills/office-hours/SKILL.md skills/office-hours/design-and-handoff.md`
Expected: no output.

- [ ] **Step 3: Confirm the heading structure looks right**

Run: `grep -n "^## \|^# " skills/office-hours/SKILL.md`
Expected: starts with `# YC Office Hours`, includes `## Phase 1: Context Gathering`, `## Phase 2A: Startup Mode — YC Product Diagnostic`, `## Phase 2B: Builder Mode`, `## Phase 2.5: Related Design Discovery`, `## Phase 2.75: Landscape Awareness`, `## Phase 3: Premise Challenge`, `## Phase 3.5: Cross-Model Second Opinion`, `## Phase 4: Alternatives Generation`, `## Visual Sketch (UI ideas only)`, `## Phase 4.5: Founder Signal Synthesis`, `## Section self-check`, `## Capture Learnings`, `## Important Rules` — no `## Visual Design Exploration`, no `## Brain Context (preflight)`, no `## Prior Learnings` as a standalone heading.

Run: `grep -n "^## " skills/office-hours/design-and-handoff.md`
Expected: `## Phase 5: Design Doc`, `## Spec Review Loop`, `## Phase 6: Handoff` — no `## Brain Calibration Write-Back`, no `## Brain Cache Background Refresh`.

- [ ] **Step 4: If anything surfaced, fix it and re-run Steps 1-3.** Otherwise, no commit needed for this task — it's read-only verification.

---

## Task 13: Pressure-test `office-hours` via subagent dispatch

Per office-hours spec's Pressure-testing plan and `writing-skills`' TDD methodology.

**Files:** none (this task produces no file changes unless testing surfaces a bug, in which case fix it and re-verify)

- [ ] **Step 1: Set up a scratch test repo**

```bash
mkdir -p /tmp/office-hours-test && cd /tmp/office-hours-test
git init -q
echo "# Test project" > README.md
git add README.md && git commit -q -m "init"
```

- [ ] **Step 2: Dispatch a subagent to run office-hours on a Startup-mode idea**

Use the `Agent` tool (general-purpose) with a prompt describing a fabricated startup idea (e.g. "I want to build a tool that helps small gyms manage class waitlists — is this worth building?") in `/tmp/office-hours-test`, asking it to run the `office-hours` skill. Run in the foreground so you can inspect the result before proceeding. In the prompt, tell the agent no `codex` binary is expected to be available so it exercises the `Agent`-tool fallback, and that it should decline the Visual Companion offer if the idea has no UI component (this one doesn't).

- [ ] **Step 3: Verify the Startup-mode run**

Check:
- The session ran the six forcing questions (Startup mode), not Builder mode.
- The cross-model second-opinion step fell back to a Claude subagent (no `codex` call attempted, or attempted and gracefully handled as unavailable).
- No Visual Companion offer was made (idea is backend-only).
- A design doc was written to `/tmp/office-hours-test/docs/superpowers/office-hours/<date>-<topic-slug>-office-hours.md`.
- The doc survived the Spec Review Loop (agent's summary mentions round count / quality score).
- The session ended with the single prose next-step line mentioning `brainstorming` and `plan-ceo-review`/`plan-eng-review` — no auto-launch, no tiered relationship messaging, no mention of `gstack` anywhere in the agent's output.

- [ ] **Step 4: Dispatch a second subagent to run office-hours on a Builder-mode, UI-shaped idea**

Same setup, fresh scratch dir, a fabricated Builder-mode idea with a clear UI component (e.g. "I want to build a weekend project — a habit tracker with a calendar view"). Run in the foreground.

- [ ] **Step 5: Verify the Builder-mode run**

Check:
- Builder mode ran (not Startup mode).
- The Visual Sketch section fired: the agent offered the Visual Companion just-in-time (not upfront), and — whether accepted or declined in the transcript — handled it per Task 7's rewrite (no reference to `$B`, no gstack browse binary).
- A design doc was written, following the same location/naming/lineage checks as Step 3.
- No dangling `gstack` references anywhere in the agent's output or the written doc.

- [ ] **Step 6: If any check in Step 3 or 5 fails, fix the relevant section in `skills/office-hours/` and re-run the corresponding subagent dispatch.**

- [ ] **Step 7: Clean up scratch repos**

```bash
rm -rf /tmp/office-hours-test
```

---

## Task 14: Final verification pass and version bump

**Files:**
- Modify: `.claude-plugin/plugin.json` (version bump)
- Modify: `.claude-plugin/marketplace.json` (version bump)

- [ ] **Step 1: Full-repo grep for stale references**

Run: `grep -rln "gstack\|plan-design-review\|design-review\b" skills/office-hours`
Expected: no output. (`design-review` check excludes the legitimate `## Visual Sketch`/`## Visual Design Exploration` heading text already removed in Task 7 — if this hits, confirm it's not a leftover mention of the unported `/design-review` skill.)

- [ ] **Step 2: Verify frontmatter is exactly two fields**

Run: `sed -n '1,4p' skills/office-hours/SKILL.md`
Expected: `---`, `name: office-hours`, `description: ...`, `---` — no other keys.

- [ ] **Step 3: Verify the file layout matches Decision 2**

Run: `find skills/office-hours -type f`
Expected: exactly `skills/office-hours/SKILL.md` and `skills/office-hours/design-and-handoff.md` — no `sections/` subfolder, no `manifest.json`.

- [ ] **Step 4: Bump the version**

Read `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` first, then bump the `version` field in both by one minor version — new skill, no breaking changes.

- [ ] **Step 5: Commit**

```bash
git add .claude-plugin/plugin.json .claude-plugin/marketplace.json
git commit -m "Bump version for office-hours skill"
```

---

## Self-Review

**1. Spec coverage** (against `docs/superpowers/specs/2026-07-20-office-hours-port-design.md`'s Decisions):
- Decision 1 (scope) — respected throughout; nothing here touches `plan-ceo-review`/`plan-eng-review` files.
- Decision 2 (naming/layout) — Task 1 (flat copy), Task 14 Step 3 (verifies no `sections/`/`manifest.json`).
- Decision 3 (frontmatter) — Task 2.
- Decision 4 (invoke-trigger content + kept forward-refs) — Task 2.
- Decision 5 (design-doc output location) — Task 9.
- Decision 6 (context-gathering translation) — Tasks 4, 5.
- Decision 7 (visual handling) — Task 7.
- Decision 8 (cross-model second opinion) — Task 6.
- Decision 9 (Spec Review Loop, drop metrics) — Task 10 Step 1.
- Decision 10 (learning capture) — Task 8 Steps 1, 6.
- Decision 11 (Phase 6 handoff, keep forward-refs) — Task 11.
- Decision 12 (prose-only hand-off, `brainstorming` cross-link) — Task 2 Step 1 (See also line), Task 11.
- Decision 13 (drop Brain Calibration/Cache Refresh + developer-profile write-back) — Task 8 Step 2, Task 10 Step 2.
- Decision 14 (core methodology ported verbatim) — nothing touches Phase 2A/2B/2.75/3/4, the design-doc templates, or Important Rules after Task 1's raw copy; they survive by construction.
- Pressure-testing plan — Task 13.

**2. Placeholder scan:** no TBD/TODO markers; every content-producing step has literal before/after text or an exact command with expected output. Pure-deletion steps (Task 3 Step 1, Task 10 Step 2, Task 11 Step 1) specify exact heading anchors rather than reproducing the ~1100 combined lines being deleted, since there is no new content to show for a deletion — each is followed by a grep-based verification step that confirms the deletion actually happened.

**3. Type/naming consistency:** `docs/superpowers/office-hours/` is used consistently as the output directory across Tasks 4, 5, 9, and the pressure-test in Task 13. The topic-slug + `Branch:`-header lineage-matching convention introduced in Task 9 is not referenced anywhere else, so there's nothing to drift out of sync with.

## Execution Handoff

Plan complete and saved to `docs/superpowers/plans/2026-07-20-office-hours-port-plan.md`. Two execution options:

1. **Subagent-Driven (recommended)** - I dispatch a fresh subagent per task, review between tasks, fast iteration
2. **Inline Execution** - Execute tasks in this session using executing-plans, batch execution with checkpoints

Which approach?
