# README Worked Example Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give README.md's "you don't need to do anything special" claim concrete proof via a short worked-example section, and clarify that the two install marketplaces are functionally identical.

**Architecture:** Two independent, additive edits to a single file: one new section, one inserted sentence. No code, no build step.

**Tech Stack:** Markdown only.

## Global Constraints

- No changes to "How it works," "The Basic Workflow," "What's Inside," "Philosophy," "License," or the telemetry note — content unchanged, only shifted down by the new section. (Spec: "Non-goals")
- The worked example is a single trigger→response moment, not a multi-stage transcript. (Spec: "Non-goals")
- The marketplace fix is one sentence stating the two marketplaces are functionally identical — no decision tree, no new tooling. (Spec: "Non-goals")

---

### Task 1: Add marketplace clarification sentence

**Files:**
- Modify: `README.md:17-30` (Installation section)

**Interfaces:**
- Consumes: nothing
- Produces: nothing consumed by Task 2 — independent edit, can be done in either order relative to Task 2.

- [ ] **Step 1: Locate the exact insertion point**

Read `README.md` lines 17-31 and confirm the content matches:

```
17	## Installation
18	
19	Superpowers is available via the [official Claude plugin marketplace](https://claude.com/plugins/superpowers):
20	
21	```bash
22	/plugin install superpowers@claude-plugins-official
23	```
24	
25	Or via the Superpowers marketplace:
26	
27	```bash
28	/plugin marketplace add obra/superpowers-marketplace
29	/plugin install superpowers@superpowers-marketplace
30	```
31	
```

If line numbers have drifted, search for the literal text `Or via the Superpowers marketplace:` and use that as the anchor.

- [ ] **Step 2: Insert the clarification sentence**

Using the Edit tool, replace:

```
Or via the Superpowers marketplace:

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```
```

with:

```
Or via the Superpowers marketplace:

```bash
/plugin marketplace add obra/superpowers-marketplace
/plugin install superpowers@superpowers-marketplace
```

Both marketplaces install the identical plugin; pick whichever you already have configured.
```

- [ ] **Step 3: Read-through verification**

Read `README.md` lines 17-32 and confirm:
- Both install blocks are unchanged
- The new sentence reads naturally as a closing note for the Installation section
- No functional difference is implied beyond "pick whichever you already have configured"

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Clarify the two install marketplaces install the identical plugin"
```

---

### Task 2: Add "See it in action" worked example section

**Files:**
- Modify: `README.md` (insert new section after Installation, before "The Basic Workflow")

**Interfaces:**
- Consumes: nothing (this task should be done after Task 1 completes, since Task 1 modifies the end of the same Installation section this task inserts after — doing Task 1 first avoids a stale insertion point)
- Produces: nothing consumed elsewhere

- [ ] **Step 1: Locate the exact insertion point**

After Task 1 is committed, read `README.md` and find the boundary between the Installation section (now ending with the "Both marketplaces install the identical plugin..." sentence) and `## The Basic Workflow`. Confirm the content matches:

```
Both marketplaces install the identical plugin; pick whichever you already have configured.

## The Basic Workflow
```

- [ ] **Step 2: Insert the new section**

Using the Edit tool, replace:

```
Both marketplaces install the identical plugin; pick whichever you already have configured.

## The Basic Workflow
```

with:

```
Both marketplaces install the identical plugin; pick whichever you already have configured.

## See it in action

> "Let's build a rate limiter for the API"

Agent: *Using brainstorming to explore the rate limiter design...*

[asks clarifying questions, proposes approaches, presents a
design for approval — before any code gets written]

## The Basic Workflow
```

- [ ] **Step 3: Read-through verification**

Read the full `README.md` end-to-end and confirm:
- Section order is: pitch → How it works → Installation (with marketplace sentence) → See it in action → The Basic Workflow → What's Inside → Philosophy → License → Visual companion telemetry
- The blockquote and italic markdown render as intended (no stray formatting)
- No other section's wording changed

Run: `grep -n "^## " README.md`
Expected output (order matters):
```
5:## How it works
17:## Installation
NN:## See it in action
MM:## The Basic Workflow
...
```
(exact line numbers `NN`/`MM` will reflect the insertions from Tasks 1 and 2)

- [ ] **Step 4: Commit**

```bash
git add README.md
git commit -m "Add worked example section to README, backing the auto-trigger claim with proof"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1 implements spec section 2 (marketplace clarification) in full. Task 2 implements spec section 1 (worked example section) in full, with Task 1's ordering dependency noted explicitly since both edits touch the same section boundary.
- **No placeholders:** Both tasks contain the full literal content to write.
- **Ordering:** Task 1 before Task 2 avoids a stale insertion point (Task 2's anchor text includes Task 1's new sentence). This is the one dependency in this plan; otherwise the two edits are independent.
