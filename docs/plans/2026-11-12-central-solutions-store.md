# Central Solutions Store Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `compound-learnings` write to a central store resolved from `SUPERPOWERS_SOLUTIONS_ROOT`, switch off its `CONCEPTS.md` seeding, session-history reading and instruction-file edits, add a read-side consult to `systematic-debugging`, and guard it all with a consistency test.

**Architecture:** Prose edits to two skills plus one bash test of static prose checks and one behavioural check. In `compound-learnings`, one authoritative `## Fork Overrides` section plus small "disabled in this fork" markers and a handful of literal-path edits; in `systematic-debugging`, one short paragraph. No script or reference file changes.

**Tech Stack:** Markdown skills; bash (3.2-compatible) test with grep/awk; python3 only to run the existing `validate-doc-claims.py`.

Spec: `docs/specs/2026-11-12-central-solutions-store-design.md`.

## Global Constraints

- Store location rule (exact semantics): if the environment variable `SUPERPOWERS_SOLUTIONS_ROOT` is set, the store is `$SUPERPOWERS_SOLUTIONS_ROOT/<repo-name>/solutions/`, where `<repo-name>` is the folder name of `git rev-parse --show-toplevel` (`_general` outside any repository); if unset, the store is `docs/solutions/` in the current repository; category subdirectories nest under it unchanged. In `compound-learnings` the resolved directory is named `$SOLUTIONS_DIR`.
- `compound-learnings` Fork Overrides has exactly five numbered items with these bold leads: `1. **Store location.**`, `2. **Never create or edit `CONCEPTS.md`.**`, `3. **Never search session history.**`, `4. **Never edit instruction files.**`, `5. **No patient data.**`.
- The disabling banner is exactly `> Disabled in this fork: see Fork Overrides. Skip this section.` and goes on the line directly after each of four headings: `## CONCEPTS.md bootstrap requests`, `#### 4. **Session History** (internal flow after launching the parallel block — automatic in Full mode, including headless)`, `### Phase 2.4: Vocabulary Capture`, `### Discoverability Check`. Four further markers contain the phrase "disabled in this fork" (case-insensitive); the file has at least eight occurrences in total and the Fork Overrides text itself does not use the phrase.
- No change to `scripts/`, `references/` or `assets/` under `skills/compound-learnings/`, no deletion of the session-history files, no change to the trigger block near the end of `skills/compound-learnings/SKILL.md`, no change to any skill other than `compound-learnings` and `systematic-debugging`.
- The consult paragraph in `systematic-debugging` treats a match as evidence to verify, never as a fix to apply, and is skipped silently when the directory does not exist.
- Editing `~/.claude/settings.json` and the vault index in `~/code/core_code/CLAUDE.md` is NOT part of Tasks 1-2; those are Task 3, done by the controller only with the user's explicit go-ahead.
- Per the user's standing rule, do not commit unless the user asks. Do not run `git add`, `git commit`, `git stash`, `git checkout` or `git reset`. Where the usual plan format has a commit step, the last step of each task is a checkpoint that leaves changes uncommitted. Commits in this repo use only the identity configured in the repo-local git config (relevant only when the user asks for a commit).
- Work on branch `feat/solutions-store` in `$HOME/code/superpowers`. Run all commands from that directory. Run tests with stdin closed (`</dev/null`).

---

### Task 1: `compound-learnings` overrides, markers and path edits (test first)

**Files:**
- Create: `tests/solutions-store/test-solutions-store.sh`
- Modify: `skills/compound-learnings/SKILL.md`

**Interfaces:**
- Produces: `tests/solutions-store/test-solutions-store.sh` (executable) with helpers `pass`, `fail`, `check`, `line_after`, variables `CL` (path to the compound-learnings SKILL.md), `SD` (path to the systematic-debugging SKILL.md), `BANNER`, and a final `if [[ "$FAILURES" -gt 0 ]]` status block that Task 2 inserts above.

- [ ] **Step 1: Write the failing test**

Create `tests/solutions-store/test-solutions-store.sh` with exactly this content, then `chmod +x tests/solutions-store/test-solutions-store.sh`:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CL="$REPO_ROOT/skills/compound-learnings/SKILL.md"
SD="$REPO_ROOT/skills/systematic-debugging/SKILL.md"
VALIDATOR="$REPO_ROOT/skills/compound-learnings/scripts/validate-doc-claims.py"
BANNER='> Disabled in this fork: see Fork Overrides. Skip this section.'

FAILURES=0
TEST_ROOT="$(mktemp -d)"
trap 'rm -rf "$TEST_ROOT"' EXIT

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

check() {
    local desc="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc"
    fi
}

line_after() {
    awk -v h="$2" '$0 == h { getline nxt; print nxt; exit }' "$1"
}

echo "compound-learnings: Fork Overrides"
check "has a Fork Overrides section" grep -q '^## Fork Overrides$' "$CL"
check "override 1: store location" grep -Fq -- '1. **Store location.**' "$CL"
check "override 2: no CONCEPTS.md" grep -Fq -- '2. **Never create or edit `CONCEPTS.md`.**' "$CL"
check "override 3: no session history" grep -Fq -- '3. **Never search session history.**' "$CL"
check "override 4: no instruction-file edits" grep -Fq -- '4. **Never edit instruction files.**' "$CL"
check "override 5: no patient data" grep -Fq -- '5. **No patient data.**' "$CL"
check "names SUPERPOWERS_SOLUTIONS_ROOT" grep -Fq -- 'SUPERPOWERS_SOLUTIONS_ROOT' "$CL"

echo "compound-learnings: disabling banners"
for heading in \
    '## CONCEPTS.md bootstrap requests' \
    '#### 4. **Session History** (internal flow after launching the parallel block — automatic in Full mode, including headless)' \
    '### Phase 2.4: Vocabulary Capture' \
    '### Discoverability Check'; do
    if [[ "$(line_after "$CL" "$heading")" == "$BANNER" ]]; then
        pass "banner directly under: $heading"
    else
        fail "banner missing directly under: $heading"
    fi
done
marker_count="$(grep -ci 'disabled in this fork' "$CL" || true)"
if [[ "$marker_count" -ge 8 ]]; then
    pass "at least 8 disabled-in-this-fork markers ($marker_count)"
else
    fail "expected at least 8 disabled-in-this-fork markers, found $marker_count"
fi

echo "compound-learnings: paths use the resolved store"
check "no literal mkdir -p docs/solutions" bash -c '! grep -Fq -- "mkdir -p docs/solutions" "$1"' _ "$CL"
check "write step uses SOLUTIONS_DIR" bash -c 'grep -F -- "Write the file: either the updated existing doc" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "directory step uses SOLUTIONS_DIR" bash -c 'grep -F -- "Create directory if needed" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "collision check uses SOLUTIONS_DIR" bash -c 'grep -F -- "the exact proposed" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "fresh glob uses SOLUTIONS_DIR" bash -c 'grep -F -- "glob the resolved store" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"

echo "a store outside git is supported by the claims validator"
doc="$TEST_ROOT/doc.md"
printf -- '---\ntitle: probe\n---\nSee `scripts/check-skill-refs.sh` and [a link](./nope.md).\n' > "$doc"
set +e
validator_out="$(python3 -I "$VALIDATOR" "$doc" 2>&1)"
validator_rc=$?
set -e
if [[ "$validator_rc" -le 1 ]] && printf '%s\n' "$validator_out" | grep -Fq 'not a git repository'; then
    pass "validate-doc-claims.py degrades gracefully outside git (exit $validator_rc)"
else
    fail "validate-doc-claims.py misbehaved outside git (exit $validator_rc)"
fi

echo "skill references still resolve"
check "check-skill-refs.sh passes" bash "$REPO_ROOT/scripts/check-skill-refs.sh"

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/solutions-store/test-solutions-store.sh </dev/null; echo "exit=$?"`
Expected: exit 1 with `STATUS: FAILED`. Failing lines include `[FAIL] has a Fork Overrides section`, all five override lines, the four `banner missing directly under: ...` lines, `expected at least 8 disabled-in-this-fork markers, found 0`, `[FAIL] no literal mkdir -p docs/solutions`, and the five path checks. The two passing lines are the validator check and `check-skill-refs.sh passes`.

- [ ] **Step 3: Edit `skills/compound-learnings/SKILL.md`**

Apply these fourteen edits with the Edit tool. Each `old` string occurs exactly once in the file; confirm that before replacing, and change nothing else in the file.

(E1) Insert the Fork Overrides section. Replace the line

```
## Purpose
```

with

```
## Fork Overrides

These take precedence over everything below.

1. **Store location.** Wherever this skill says `docs/solutions/`, use the resolved store directory, called `$SOLUTIONS_DIR` below. Resolve it once, before any other work: if `printenv SUPERPOWERS_SOLUTIONS_ROOT` prints a path, `$SOLUTIONS_DIR` is `$SUPERPOWERS_SOLUTIONS_ROOT/<repo-name>/solutions/`, where `<repo-name>` is the folder name of `git rev-parse --show-toplevel` (`_general` when not inside a repository); otherwise `$SOLUTIONS_DIR` is `docs/solutions/` in the current repository. Category subdirectories nest under it unchanged.
2. **Never create or edit `CONCEPTS.md`.** Skip the bootstrap request handling, Phase 2.4 and every vocabulary-capture step.
3. **Never search session history.** Skip step 4 of Phase 1 and every use of `scripts/session-history/` and `references/agents/session-historian.md`; do not read session transcripts.
4. **Never edit instruction files.** Skip the Discoverability Check and the discoverability steps in Lightweight mode.
5. **No patient data.** A solution doc never contains patient identifiers, data values or row contents; describe problems and fixes with schema, column and model names only.

## Purpose
```

(E2) Replace the heading line `## CONCEPTS.md bootstrap requests` with these two lines:

```
## CONCEPTS.md bootstrap requests
> Disabled in this fork: see Fork Overrides. Skip this section.
```

(E3) Replace the heading line `#### 4. **Session History** (internal flow after launching the parallel block — automatic in Full mode, including headless)` with:

```
#### 4. **Session History** (internal flow after launching the parallel block — automatic in Full mode, including headless)
> Disabled in this fork: see Fork Overrides. Skip this section.
```

(E4) Replace the heading line `### Phase 2.4: Vocabulary Capture` with:

```
### Phase 2.4: Vocabulary Capture
> Disabled in this fork: see Fork Overrides. Skip this section.
```

(E5) Replace the heading line `### Discoverability Check` with:

```
### Discoverability Check
> Disabled in this fork: see Fork Overrides. Skip this section.
```

(E6) Replace the text `**Session history — an automatic probe in Full mode, never a question.**` (it starts a paragraph) with `**Disabled in this fork (see Fork Overrides): do not run the session-history probe.** **Session history — an automatic probe in Full mode, never a question.**`

(E7) Replace the text `- **Then** run the internal session-history discovery/extraction/synthesis flow` with `- (Disabled in this fork: skip this bullet; see Fork Overrides.) **Then** run the internal session-history discovery/extraction/synthesis flow`

(E8) Replace the text `4. **Vocabulary capture (update-only)**:` with `4. **Vocabulary capture (update-only)** — disabled in this fork; skip this step (see Fork Overrides):`

(E9) Replace the text `5. **Read-only discoverability check**:` with `5. **Read-only discoverability check** — disabled in this fork; skip this step (see Fork Overrides):`

(E10) Replace the text ``**CRITICAL — glob `docs/solutions/` fresh every run.**`` with ``**CRITICAL — glob the resolved store (`$SOLUTIONS_DIR`) fresh every run.**``

(E11) Replace the text ``- Searches `docs/solutions/` for related documentation`` with ``- Searches the resolved store (`$SOLUTIONS_DIR`) for related documentation``

(E12) Replace the text ``6. Create directory if needed: `mkdir -p docs/solutions/[category]/` `` (without the trailing space) with ``6. Create directory if needed: `mkdir -p "$SOLUTIONS_DIR/[category]/"` ``

(E13) Replace the text ``7. Write the file: either the updated existing doc or the new `docs/solutions/[category]/[filename].md` `` (without the trailing space) with ``7. Write the file: either the updated existing doc or the new `$SOLUTIONS_DIR/[category]/[filename].md` ``

(E14) Replace the text ``the exact proposed `docs/solutions/[category]/[filename].md` path`` with ``the exact proposed `$SOLUTIONS_DIR/[category]/[filename].md` path``

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/solutions-store/test-solutions-store.sh </dev/null; echo "exit=$?"`
Expected: every line `[PASS]`, ending `STATUS: PASSED` and `exit=0`. The marker line reads `at least 8 disabled-in-this-fork markers (8)`.

- [ ] **Step 5: Lint and related checks**

Run:

```bash
bash scripts/lint-shell.sh tests/solutions-store/test-solutions-store.sh; echo "lint exit=$?"
bash scripts/check-skill-refs.sh | tail -1
git diff --stat -- skills/compound-learnings | tail -2
git diff --stat -- skills/compound-learnings/scripts skills/compound-learnings/references skills/compound-learnings/assets | wc -l
```

Expected: `lint exit=0`; the refs check reports all references resolve; the diff stat shows only `skills/compound-learnings/SKILL.md` changed; the last command prints `0` (no change under `scripts/`, `references/` or `assets/`).

- [ ] **Step 6: Checkpoint (do not commit)**

Run: `git status --short`
Expected: `skills/compound-learnings/SKILL.md` modified; `tests/solutions-store/` untracked; the spec and this plan untracked. Leave everything uncommitted.

---

### Task 2: `systematic-debugging` consult step (test first)

**Files:**
- Modify: `tests/solutions-store/test-solutions-store.sh`
- Modify: `skills/systematic-debugging/SKILL.md`

**Interfaces:**
- Consumes: the test file, helpers `pass`, `fail`, `check`, variables `CL`, `SD` and the final `if [[ "$FAILURES" -gt 0 ]]` block from Task 1.
- Produces: a paragraph beginning `**Check for a known solution first.**` in Phase 1 of `skills/systematic-debugging/SKILL.md`, before the numbered steps, using the same variable name as `compound-learnings`.

- [ ] **Step 1: Write the failing tests**

In `tests/solutions-store/test-solutions-store.sh`, insert this block immediately above the line `echo "skill references still resolve"`:

```bash
echo "systematic-debugging: consult step"
check "has the known-solution paragraph" grep -Fq -- '**Check for a known solution first.**' "$SD"
check "names SUPERPOWERS_SOLUTIONS_ROOT" grep -Fq -- 'SUPERPOWERS_SOLUTIONS_ROOT' "$SD"
consult_line="$(grep -n -F -- '**Check for a known solution first.**' "$SD" | head -n 1 | cut -d: -f1)"
first_step_line="$(grep -n -F -- '1. **Read Error Messages Carefully**' "$SD" | head -n 1 | cut -d: -f1)"
if [[ -n "$consult_line" && -n "$first_step_line" && "$consult_line" -lt "$first_step_line" ]]; then
    pass "the consult paragraph comes before the numbered steps"
else
    fail "the consult paragraph must come before '1. **Read Error Messages Carefully**' (consult=${consult_line:-none}, step=${first_step_line:-none})"
fi
check "treats a match as evidence, not a fix" grep -Fq -- 'evidence to verify' "$SD"
check "derives the repo name from the main working tree" grep -Fq -- 'git rev-parse --git-common-dir' "$SD"
check "skips silently when the store is missing" grep -Fq -- 'If the directory does not exist, skip this.' "$SD"

echo "both skills use the same variable name"
cl_vars="$(grep -o 'SUPERPOWERS_[A-Z_]*' "$CL" | sort -u | tr '\n' ' ')"
sd_vars="$(grep -o 'SUPERPOWERS_[A-Z_]*' "$SD" | sort -u | tr '\n' ' ')"
if [[ -n "$cl_vars" && "$cl_vars" == "$sd_vars" ]]; then
    pass "same SUPERPOWERS_* variables in both skills ($cl_vars)"
else
    fail "variable names differ: compound-learnings=[$cl_vars] systematic-debugging=[$sd_vars]"
fi

```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/solutions-store/test-solutions-store.sh </dev/null; echo "exit=$?"`
Expected: exit 1 with `STATUS: FAILED`. Failing lines: `has the known-solution paragraph`, `names SUPERPOWERS_SOLUTIONS_ROOT` (the systematic-debugging one), `the consult paragraph must come before ...`, `treats a match as evidence, not a fix`, `skips silently when the store is missing`, and `variable names differ`. All Task 1 assertions still `[PASS]`.

- [ ] **Step 3: Edit `skills/systematic-debugging/SKILL.md`**

Replace this exact text (it occurs once, at the start of Phase 1):

```
**BEFORE attempting ANY fix:**

1. **Read Error Messages Carefully**
```

with:

```
**BEFORE attempting ANY fix:**

**Check for a known solution first.** If a solutions store exists, search it for the error message or symptom: with `SUPERPOWERS_SOLUTIONS_ROOT` set to an absolute path, the store is `$SUPERPOWERS_SOLUTIONS_ROOT/<repo-name>/solutions/` (`<repo-name>` is the folder name of the main working tree, `basename "$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"`, the same from a subdirectory or a linked worktree; `_general` outside a repository); otherwise it is `docs/solutions/` at the repository root. A match is evidence to verify against the current code, not a fix to apply; carry on with the steps below either way. If the directory does not exist, skip this.

1. **Read Error Messages Carefully**
```

Change nothing else in the file.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/solutions-store/test-solutions-store.sh </dev/null; echo "exit=$?"`
Expected: every line `[PASS]`, ending `STATUS: PASSED` and `exit=0`; the last group prints `same SUPERPOWERS_* variables in both skills (SUPERPOWERS_SOLUTIONS_ROOT )`.

- [ ] **Step 5: Lint and related checks**

Run:

```bash
bash scripts/lint-shell.sh tests/solutions-store/test-solutions-store.sh; echo "lint exit=$?"
bash scripts/check-skill-refs.sh | tail -1
git diff --stat -- skills | tail -3
bash scripts/upstream-drift.sh >/dev/null 2>&1; echo "drift script present: exit=$?"
```

Expected: `lint exit=0`; refs resolve; the diff stat lists exactly `skills/compound-learnings/SKILL.md` and `skills/systematic-debugging/SKILL.md`. The last command may report a non-zero exit because `scripts/upstream-drift.sh` is on a different branch; report the value and do not try to fix it.

- [ ] **Step 6: Checkpoint (do not commit)**

Run: `git status --short`
Expected: both skill files modified; `tests/solutions-store/` untracked; the spec and this plan untracked. Leave everything uncommitted.

---

### Task 3: Vault index and environment variable (controller only, with the user's go-ahead)

Not for a subagent. These touch files outside the fork, so each step needs the user's explicit confirmation first.

- [ ] **Step 1: Add one row to the vault index.** In `~/code/core_code/CLAUDE.md`, in the "Vault index" table, append this row after the last existing row (the vault is read-write by the workspace rules; confirm with the user before editing):

```
| `docs/<repo-name>/solutions/` | Solved-problem write-ups per repo, written by the `compound-learnings` skill (the central solutions store). Search here before debugging a problem that may have happened before. |
```

- [ ] **Step 2: Set the variable.** With the user's confirmation, add `SUPERPOWERS_SOLUTIONS_ROOT` to the `env` block of `~/.claude/settings.json`, value `/Users/<you>/code/core_code/docs` (use the `update-config` skill; show the exact change first). Until this is set, both skills fall back to `docs/solutions/` in the current repository.

- [ ] **Step 3: Verify.** In a new session, `printenv SUPERPOWERS_SOLUTIONS_ROOT` prints the path; the store for a session in `~/code/data-tools` resolves to `/Users/<you>/code/core_code/docs/data-tools/solutions/`. Report what was verified and what was not.


---

## Post-review amendments (applied after Task 1 was executed)

The Task 1 review found gaps in the design, fixed in a follow-up edit before Task 2: the resolved `$SOLUTIONS_DIR` is now passed into every Phase 1 subagent prompt and the last literal category-narrowing path is converted; the store variable must be an absolute path (settings env values are not tilde-expanded, and a relative path would create directories inside the repository); the repo name is derived from the main working tree with `git rev-parse --git-common-dir` so linked worktrees do not scatter one project's learnings (proven in a throwaway repo); the repository-root fallback and the outside-a-repo behaviour are stated; and the remaining passive mentions of the disabled behaviours got "disabled in this fork" markers. Task 2's consult paragraph and test were updated to the same derivation. The code blocks above for Task 1 are the plan as first written.

The final whole-branch review added further fixes: the no-patient-data rule is passed to the Phase 1 subagents and applied before the write step (the Solution Extractor is told to capture exact error messages, which can echo row values); a set-but-empty variable counts as set; outside a repository the repo name falls back to `_general`; the Lightweight-mode `CONCEPTS.md` mention and the output templates got disabled-in-this-fork notes; and the test's grep assignments gained `|| true` so a red run reports failures instead of aborting. The repository-wide follow-up that remains is the skill's frontmatter `description` (line 3), which still advertises `docs/solutions/` and `CONCEPTS.md`: changing it alters the generated routing table and README catalog, which live on a different branch, so it is deferred until those branches merge.
