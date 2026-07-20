# CONTRIBUTING.md + Description-Skip Warning Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a minimal `CONTRIBUTING.md` at repo root that points contributors to `skills/writing-skills/SKILL.md`, and relocate a condensed version of the description-skip warning to where a contributor actually writes skill frontmatter.

**Architecture:** Two independent, additive documentation changes. No code, no build step, no new tooling. Each change is a self-contained commit.

**Tech Stack:** Markdown only.

## Global Constraints

- Docs-only. No lint script, no CI workflow, no new scripts/ entries. (Spec: "Non-goals")
- `CONTRIBUTING.md` must not invent PR checklists, branch-naming rules, or testing conventions that don't exist elsewhere in the repo. (Spec: "Non-goals")
- The existing "Skill Discovery Optimization" section in `skills/writing-skills/SKILL.md` (currently lines 142-199) must be left completely unchanged — the fix is additive only. (Spec: "Design, section 2")
- `CONTRIBUTING.md` length target: well under 50 lines. (Spec: "Design, section 1")

---

### Task 1: Create CONTRIBUTING.md

**Files:**
- Create: `CONTRIBUTING.md` (repo root)

**Interfaces:**
- Consumes: nothing (standalone new file)
- Produces: a root-level `CONTRIBUTING.md` that other future work (e.g. README updates) may link to. No functions/exports — this is a docs file.

- [ ] **Step 1: Write CONTRIBUTING.md**

Create `CONTRIBUTING.md` at the repo root with exactly this content:

```markdown
# Contributing

Superpowers is a library of markdown-defined agent skills (each a `SKILL.md`
plus optional `references/`). Skills are the primary way to contribute to
this repo.

## Adding or editing a skill

Start with [`skills/writing-skills/SKILL.md`](skills/writing-skills/SKILL.md)
— it defines the TDD-for-skills methodology this repo requires: run a
baseline scenario with a naive agent before writing anything, write the
skill to close the observed gap, then verify with pressure-test subagents.
Skills that skip this process tend to under- or over-specify what they're
teaching.

## Reporting issues

Open an issue on this repo's GitHub page with a description of the problem
and, if applicable, the prompt or scenario that triggered it.
```

- [ ] **Step 2: Read-through verification**

Read the file back and confirm:
- It renders as valid markdown (headings, link, and paragraphs display correctly)
- The link `skills/writing-skills/SKILL.md` is a correct relative path from repo root
- No PR checklist, branch-naming rule, or testing-process claim was introduced (Global Constraints)
- Total length is under 50 lines

Run: `wc -l CONTRIBUTING.md`
Expected: a number well under 50.

- [ ] **Step 3: Commit**

```bash
git add CONTRIBUTING.md
git commit -m "Add CONTRIBUTING.md pointing contributors to writing-skills"
```

---

### Task 2: Relocate description-skip warning to the frontmatter section

**Files:**
- Modify: `skills/writing-skills/SKILL.md:99-105`

**Interfaces:**
- Consumes: nothing (standalone edit to an existing file)
- Produces: nothing consumed by other tasks. This task and Task 1 are independent and can be done in either order.

- [ ] **Step 1: Locate the exact insertion point**

Read `skills/writing-skills/SKILL.md` lines 95-110 and confirm the content matches:

```
95	**Frontmatter (YAML):**
96	- Two required fields: `name` and `description` (see [agentskills.io/specification](https://agentskills.io/specification) for all supported fields)
97	- Max 1024 characters total
98	- `name`: Use letters, numbers, and hyphens only (no parentheses, special chars)
99	- `description`: Third-person, describes ONLY when to use (NOT what it does)
100	  - Start with "Use when..." to focus on triggering conditions
101	  - Include specific symptoms, situations, and contexts
102	  - **NEVER summarize the skill's process or workflow** (see SDO section for why)
103	  - Keep under 500 characters if possible
104	
105	```markdown
```

If the line numbers have drifted (e.g. from an unrelated prior edit), search for the literal text `Keep under 500 characters if possible` instead and use the line immediately after it as the insertion point.

- [ ] **Step 2: Insert the condensed warning**

Using the Edit tool, replace:

```
  - Keep under 500 characters if possible

```markdown
```

with:

```
  - Keep under 500 characters if possible

> ⚠️ **Before you write this field:** a description that summarizes the
> skill's workflow will cause agents to follow the description instead of
> reading the skill — this has been reproduced. See "Skill Discovery
> Optimization" below for the full explanation and examples.

```markdown
```

(Preserve the blank line before and after the new blockquote, matching the surrounding style.)

- [ ] **Step 3: Verify the SDO section is untouched**

Run: `grep -n "Skill Discovery Optimization" skills/writing-skills/SKILL.md`
Expected: one match, and reading 20 lines from that match onward shows the existing CRITICAL callout and bad/good examples exactly as before — no duplicated or altered wording.

- [ ] **Step 4: Read-through verification**

Read `skills/writing-skills/SKILL.md` lines 95-115 (the shifted range) end-to-end and confirm:
- The new blockquote reads naturally between the frontmatter bullets and the `SKILL.md` template code block
- It does not duplicate the SDO section's wording verbatim (it's a pointer + one-sentence summary, not a copy)
- No other section of the file was altered

- [ ] **Step 5: Commit**

```bash
git add skills/writing-skills/SKILL.md
git commit -m "Surface description-skip warning at the point contributors write frontmatter"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1 implements spec section 1 (CONTRIBUTING.md) in full. Task 2 implements spec section 2 (condensed warning callout) in full, explicitly preserving the SDO section per the spec's non-goal of no restructuring.
- **No placeholders:** Both tasks contain the full literal content to write, not descriptions of it.
- **Independence:** Tasks 1 and 2 touch different files and have no ordering dependency; either can be done first, or both can be dispatched in parallel if using subagent-driven-development.
