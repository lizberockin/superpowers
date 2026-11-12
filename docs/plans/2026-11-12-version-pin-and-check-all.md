# Unpin the Plugin Version and Add `check-all.sh` Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the fork's installed copy track its commits, fix the routing-table generator and the stale generated content, and add one `scripts/check-all.sh` gate with an opt-in pre-commit hook.

**Architecture:** Four independent-enough tasks in dependency order: unpin the manifests; fix the routing generator and regenerate the injected table; fix the catalog test and regenerate the README catalog; add `check-all.sh` that runs every deterministic guard and a test that exercises it against a throwaway repository of stub steps.

**Tech Stack:** bash (3.2-compatible), awk, sed, git, the `claude` CLI (`claude plugin validate`), ShellCheck for lint.

Spec: `docs/specs/2026-11-12-version-pin-and-check-all-design.md`.

## Global Constraints

- Remove the `version` key from `.claude-plugin/plugin.json` and from the plugin entry in `.claude-plugin/marketplace.json`; set `homepage` and `repository` in `plugin.json` to `https://github.com/lizberockin/superpowers`; keep the `author` credit as is; change nothing else in the manifests.
- The routing generator skips any skill whose frontmatter has `disable-model-invocation: true`, and uses a description verbatim as the trigger clause when it does not start with "Use when " or "You MUST"; keep the existing truncation rules and the documented latent edge cases.
- `scripts/check-all.sh`: self-contained bash following `scripts/check-skill-refs.sh` conventions (usage header comment, `set -euo pipefail`); runs from the repo root regardless of caller directory; prints one `PASS`, `FAIL` or `SKIP` line per step; keeps going after a failure; exits 1 if any step failed, else 0; a step whose tool is missing is a visible `SKIP`.
- Steps in order: catalog `--check`; routing `--check`; `check-skill-refs.sh`; `lint-shell.sh` in default changed-files mode (not `--all`); the deterministic suites (`tests/hooks/test-*.sh`, `tests/shell-lint/test-*.sh`, `tests/skill-catalog/test-*.sh`, `tests/upstream-drift/test-*.sh`, `tests/check-all/test-*.sh`, `tests/claude-code/test-sdd-workspace.sh`; a missing directory is ignored); `claude plugin validate .`; a guard that fails if either manifest has a `version` key.
- Never run `tests/claude-code/*` other than `test-sdd-workspace.sh`, `tests/explicit-skill-requests/`, or `tests/brainstorm-server/` from `check-all.sh`. No CI wiring. The pre-commit hook is opt-in (`git config core.hooksPath .githooks`) and is never enabled automatically.
- Tests must not hardcode skill counts that depend on the real `skills/` directory.
- Per the user's standing rule, do not commit unless the user asks. Where the usual plan format has a commit step, the last step of each task is a checkpoint that leaves changes uncommitted. Do not run `git add`, `git commit`, `git stash`, `git checkout` or `git reset`.
- Work on branch `feat/version-pin-and-check-all` in `$HOME/code/superpowers`. Run all commands from that directory.

---

### Task 1: Unpin the manifests

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.claude-plugin/marketplace.json`

**Interfaces:**
- Produces: neither manifest contains the text `"version"` (Task 4's guard step asserts this); `claude plugin validate .` still reports `Validation passed`.

- [ ] **Step 1: Confirm the current state (the failing condition)**

Run: `grep -c '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json`
Expected: `.claude-plugin/plugin.json:1` and `.claude-plugin/marketplace.json:1` (each file pins a version).

- [ ] **Step 2: Edit the manifests**

Replace the entire contents of `.claude-plugin/plugin.json` with:

```json
{
  "name": "superpowers",
  "description": "Core skills library for Claude Code: TDD, debugging, collaboration patterns, and proven techniques",
  "author": {
    "name": "Jesse Vincent",
    "email": "jesse@fsck.com"
  },
  "homepage": "https://github.com/lizberockin/superpowers",
  "repository": "https://github.com/lizberockin/superpowers",
  "license": "MIT",
  "keywords": [
    "skills",
    "tdd",
    "debugging",
    "collaboration",
    "best-practices",
    "workflows"
  ]
}
```

In `.claude-plugin/marketplace.json`, delete exactly this one line from the plugin entry (leave every other line unchanged):

```
      "version": "6.3.0",
```

- [ ] **Step 3: Verify**

Run:

```bash
grep -c '"version"' .claude-plugin/plugin.json .claude-plugin/marketplace.json
python3 -c 'import json; [json.load(open(f)) for f in (".claude-plugin/plugin.json", ".claude-plugin/marketplace.json")]; print("json ok")'
claude plugin validate . 2>&1 | tail -2
```

Expected: `.claude-plugin/plugin.json:0` and `.claude-plugin/marketplace.json:0`; `json ok`; `claude plugin validate .` exits 0 and its last line is `✔ Validation passed with warnings` (the warnings are "No version specified" and the pre-existing missing-icon notice).

- [ ] **Step 4: Checkpoint (do not commit)**

Run: `git status --short`
Expected: exactly the two manifest files shown as modified (plus the spec and this plan as untracked). Leave everything uncommitted.

---

### Task 2: Fix the routing-table generator, then regenerate the injected table

**Files:**
- Modify: `tests/skill-catalog/test-generate-routing-table.sh`
- Modify: `scripts/generate-routing-table.sh`
- Modify (by running the generator): `skills/using-superpowers/SKILL.md`

**Interfaces:**
- Produces: the generator honours an optional `SKILLS_DIR` environment variable (default `$REPO_ROOT/skills`) so tests can point it at fixture skills; the generated block no longer contains `disable-model-invocation: true` skills and prints non-"Use when" descriptions verbatim as `- <description> → superpowers:<name>`.

- [ ] **Step 1: Write the failing tests**

In `tests/skill-catalog/test-generate-routing-table.sh`:

(a) Replace the whole function `test_extraction_produces_17_entries_alphabetical` (from its `test_extraction_produces_17_entries_alphabetical() {` line to its closing `}`) with these two functions:

```bash
count_routable_skills() {
    local f name n=0
    for f in "$REPO_ROOT"/skills/*/SKILL.md; do
        name="$(awk 'NR==1 && $0=="---" { fm=1; next } fm && $0=="---" { exit } fm && /^name:/ { sub(/^name: */, ""); print; exit }' "$f")"
        [ "$name" = "using-superpowers" ] && continue
        if awk 'NR==1 && $0=="---" { fm=1; next } fm && $0=="---" { exit } fm && /^disable-model-invocation: *true/ { found=1 } END { exit !found }' "$f"; then
            continue
        fi
        n=$((n + 1))
    done
    echo "$n"
}

test_extraction_produces_one_entry_per_routable_skill_alphabetical() {
    local desc="extraction produces one entry per routable skill (excludes using-superpowers and user-only skills), alphabetically sorted"
    local target expected
    target="$(make_target_file "extraction.md")"
    expected="$(count_routable_skills)"

    "$GENERATOR" "$target" > /dev/null

    local block
    block="$(sed -n '/<!-- BEGIN GENERATED ROUTING TABLE -->/,/<!-- END GENERATED ROUTING TABLE -->/p' "$target" | sed '1d;$d')"

    local count
    count="$(printf '%s\n' "$block" | grep -c 'superpowers:')"
    if [ "$count" -eq "$expected" ]; then
        pass "$desc ($expected entries)"
    else
        fail "$desc (expected $expected entries, got $count)"
        printf '%s\n' "$block" | sed 's/^/      /'
    fi

    if printf '%s\n' "$block" | grep -q 'superpowers:using-superpowers'; then
        fail "$desc (using-superpowers incorrectly routes to itself)"
    else
        pass "$desc (using-superpowers excluded)"
    fi

    local names sorted_names
    names="$(printf '%s\n' "$block" | sed -n 's/.*→ superpowers:\([a-z0-9-]*\)$/\1/p')"
    sorted_names="$(printf '%s\n' "$names" | sort)"
    if [ "$names" = "$sorted_names" ]; then
        pass "$desc (alphabetically sorted)"
    else
        fail "$desc (not alphabetically sorted)"
    fi
}
```

(b) Add these functions immediately above the line `test_check_mode_exits_0_when_in_sync() {`:

```bash
make_skills_dir() {
    local dir="$TEST_ROOT/skills-fixture"
    rm -rf "$dir"
    mkdir -p "$dir/alpha" "$dir/beta" "$dir/gamma" "$dir/using-superpowers"
    printf -- '---\nname: alpha\ndescription: Use when something happens - mechanism text follows\n---\n' > "$dir/alpha/SKILL.md"
    printf -- '---\nname: beta\ndescription: Only the user invokes this one.\ndisable-model-invocation: true\n---\n' > "$dir/beta/SKILL.md"
    printf -- '---\nname: gamma\ndescription: Diagnosis loop for hard bugs. Use when the user says "diagnose".\n---\n' > "$dir/gamma/SKILL.md"
    printf -- '---\nname: using-superpowers\ndescription: Use when starting any conversation\n---\n' > "$dir/using-superpowers/SKILL.md"
    printf '%s\n' "$dir"
}

test_skips_skills_that_disable_model_invocation() {
    local desc="skills with disable-model-invocation: true are left out of the routing table"
    local target skills
    target="$(make_target_file "skip-user-only.md")"
    skills="$(make_skills_dir)"

    SKILLS_DIR="$skills" "$GENERATOR" "$target" > /dev/null

    if grep -q 'superpowers:beta' "$target"; then
        fail "$desc (beta is listed)"
    elif grep -Fxq -- '- Use when something happens → superpowers:alpha' "$target"; then
        pass "$desc"
    else
        fail "$desc (alpha line missing or wrong)"
        grep 'superpowers:' "$target" | sed 's/^/      /'
    fi
}

test_description_without_use_when_is_verbatim() {
    local desc="a description that does not start with 'Use when' is used verbatim, with no prefix added"
    local target skills expected
    target="$(make_target_file "verbatim.md")"
    skills="$(make_skills_dir)"
    expected='- Diagnosis loop for hard bugs. Use when the user says "diagnose". → superpowers:gamma'

    SKILLS_DIR="$skills" "$GENERATOR" "$target" > /dev/null

    if grep -Fxq -- "$expected" "$target"; then
        pass "$desc"
    else
        fail "$desc"
        grep 'superpowers:gamma' "$target" | sed 's/^/      /'
    fi
}

```

(c) In the run list at the bottom, replace the line `test_extraction_produces_17_entries_alphabetical` with these three lines:

```bash
test_extraction_produces_one_entry_per_routable_skill_alphabetical
test_skips_skills_that_disable_model_invocation
test_description_without_use_when_is_verbatim
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/skill-catalog/test-generate-routing-table.sh </dev/null`
Expected: exit 1. `[FAIL]` for the entry-count check (the generator still lists the user-only skills), `[FAIL] skills with disable-model-invocation: true are left out ...` (the generator ignores `SKILLS_DIR`), `[FAIL] a description that does not start with 'Use when' ...`, and `[FAIL] --check exits 0 against the real skills/using-superpowers/SKILL.md`.

- [ ] **Step 3: Write the implementation**

In `scripts/generate-routing-table.sh` make these four edits.

(a) Replace the two header comment lines

```
# Generate the "Full Routing Reference" block in using-superpowers/SKILL.md
# from every other skill's frontmatter description.
```

with

```
# Generate the "Full Routing Reference" block in using-superpowers/SKILL.md
# from every other skill's frontmatter description. Skills marked
# `disable-model-invocation: true` are left out: they are user-invoked only.
# Set SKILLS_DIR to read skills from somewhere other than <repo>/skills.
```

and replace the line `SELF_SKILL="using-superpowers"` with:

```bash
SELF_SKILL="using-superpowers"
SKILLS_DIR="${SKILLS_DIR:-$REPO_ROOT/skills}"
```

(b) Replace this comment-and-function pair:

```bash
# Strips a leading "Use when " prefix, then truncates at the first
# " — " (em dash) or " - " (hyphen) separator, whichever comes first.
# Descriptions use these inconsistently to separate the trigger clause
# from the mechanism/rationale clause that follows.
```

with:

```bash
# Truncates at the first " — " (em dash) or " - " (hyphen) separator,
# whichever comes first. Descriptions use these inconsistently to
# separate the trigger clause from the mechanism/rationale clause that
# follows. The description is otherwise used verbatim, with no prefix
# added or removed.
```

and replace the function body

```bash
extract_trigger_clause() {
  local desc="$1"
  case "$desc" in
    "Use when "*) desc="${desc#Use when }" ;;
  esac
  printf '%s' "$desc" | sed -E 's/ (—|-) .*$//'
}
```

with:

```bash
extract_trigger_clause() {
  local desc="$1"
  printf '%s' "$desc" | sed -E 's/ (—|-) .*$//'
}
```

(c) In `generate_routing_block`, replace the loop header `for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do` with `for skill_file in "$SKILLS_DIR"/*/SKILL.md; do`, and insert this line immediately after the line `[ "$name" = "$SELF_SKILL" ] && continue`:

```bash
    [ "$(extract_frontmatter_field "$skill_file" "disable-model-invocation")" = "true" ] && continue
```

(d) Replace the final `while` body

```bash
  done | sort -k1,1 | while IFS=$'\t' read -r name clause; do
    case "$clause" in
      "Use when "*|"You MUST"*) printf -- '- %s → superpowers:%s\n' "$clause" "$name" ;;
      *) printf -- '- Use when %s → superpowers:%s\n' "$clause" "$name" ;;
    esac
  done
```

with:

```bash
  done | sort -k1,1 | while IFS=$'\t' read -r name clause; do
    printf -- '- %s → superpowers:%s\n' "$clause" "$name"
  done
```

- [ ] **Step 4: Run the tests to verify what now passes**

Run: `bash tests/skill-catalog/test-generate-routing-table.sh </dev/null`
Expected: every fixture-based and extraction test `[PASS]`; the only remaining `[FAIL]` is `--check exits 0 against the real skills/using-superpowers/SKILL.md` (the real table has not been regenerated yet).

- [ ] **Step 5: Regenerate the real routing table and re-run**

Run:

```bash
bash scripts/generate-routing-table.sh
bash scripts/generate-routing-table.sh --check; echo "check exit=$?"
bash tests/skill-catalog/test-generate-routing-table.sh </dev/null | tail -3
git diff --stat skills/using-superpowers/SKILL.md
grep -c 'Use when A relentless\|Use when Diagnosis\|Use when Compact the' skills/using-superpowers/SKILL.md
```

Expected: `Regenerated routing table in ...`; `Routing table is in sync.` with `check exit=0`; the test ends `All tests passed.`; the diff stat shows only `skills/using-superpowers/SKILL.md` changed (added lines inside the generated block only); the final `grep -c` prints `0` (no oddly prefixed lines). `grill-me`, `handoff`, `loop-me`, `teach`, `to-questionnaire` and `wait-what` do not appear in the block, and `diagnosing-bugs` does.

- [ ] **Step 6: Checkpoint (do not commit)**

Run: `git status --short`
Expected: the two manifest files, `scripts/generate-routing-table.sh`, `tests/skill-catalog/test-generate-routing-table.sh` and `skills/using-superpowers/SKILL.md` modified. Leave uncommitted.

---

### Task 3: Fix the catalog test's hardcoded count, then regenerate the README catalog

**Files:**
- Modify: `tests/skill-catalog/test-generate-skill-catalog.sh`
- Modify (by running the generator): `README.md`

**Interfaces:**
- Produces: the catalog test derives its expected bullet count from `skills/*/SKILL.md` instead of a literal; `scripts/generate-skill-catalog.sh --check` exits 0 on the real README.

- [ ] **Step 1: Write the test change**

In `tests/skill-catalog/test-generate-skill-catalog.sh`, replace the whole function `test_extraction_produces_18_skills_alphabetical` (from its `test_extraction_produces_18_skills_alphabetical() {` line to its closing `}`) with:

```bash
test_extraction_produces_one_bullet_per_skill_alphabetical() {
    local desc="extraction produces one bullet per skill, alphabetically sorted"
    local target expected
    target="$(make_target_file "extraction.md")"
    expected="$(ls -d "$REPO_ROOT"/skills/*/SKILL.md | wc -l | tr -d ' ')"

    "$GENERATOR" "$target" > /dev/null

    local block
    block="$(sed -n '/<!-- BEGIN GENERATED SKILL CATALOG -->/,/<!-- END GENERATED SKILL CATALOG -->/p' "$target" | sed '1d;$d')"

    local count
    count="$(printf '%s\n' "$block" | grep -c '^- \*\*')"
    if [ "$count" -eq "$expected" ]; then
        pass "$desc ($count bullets)"
    else
        fail "$desc (expected $expected bullets, got $count)"
        printf '%s\n' "$block" | sed 's/^/      /'
    fi

    local names sorted_names
    names="$(printf '%s\n' "$block" | sed -n 's/^- \*\*\([a-z0-9-]*\)\*\*.*/\1/p')"
    sorted_names="$(printf '%s\n' "$names" | sort)"
    if [ "$names" = "$sorted_names" ]; then
        pass "$desc (alphabetically sorted)"
    else
        fail "$desc (not alphabetically sorted)"
    fi
}
```

and in the run list at the bottom replace the line `test_extraction_produces_18_skills_alphabetical` with `test_extraction_produces_one_bullet_per_skill_alphabetical`.

- [ ] **Step 2: Run the test to see the expected remaining failure**

Run: `bash tests/skill-catalog/test-generate-skill-catalog.sh </dev/null`
Expected: the extraction assertions now `[PASS]` (count computed from the real directory); the only `[FAIL]` is `--check exits 0 against the real README.md` (the README catalog is stale).

- [ ] **Step 3: Regenerate the README catalog**

Run:

```bash
bash scripts/generate-skill-catalog.sh
bash scripts/generate-skill-catalog.sh --check; echo "check exit=$?"
bash tests/skill-catalog/test-generate-skill-catalog.sh </dev/null | tail -3
git diff --stat README.md
```

Expected: `Regenerated ...`; `Skill catalog is in sync.` with `check exit=0`; the test ends `All tests passed.`; the diff stat shows only `README.md` changed, with additions only inside the generated catalog block (the 10 previously missing skills).

- [ ] **Step 4: Checkpoint (do not commit)**

Run: `git status --short`
Expected: previous modified files plus `README.md` and `tests/skill-catalog/test-generate-skill-catalog.sh`. Leave uncommitted.

---

### Task 4: `scripts/check-all.sh`, its test, the opt-in hook, and the docs line

**Files:**
- Create: `tests/check-all/test-check-all.sh`
- Create: `scripts/check-all.sh`
- Create: `.githooks/pre-commit`
- Modify: `CONTRIBUTING.md` (append a section)

**Interfaces:**
- Consumes: the manifests without a `version` key (Task 1); the in-sync generated content (Tasks 2 and 3).
- Produces: `scripts/check-all.sh` printing lines exactly of the form `PASS  <step>`, `FAIL  <step>` and `SKIP  <step> (<reason>)` (two spaces after the four-letter label), then a final line `check-all: <P> passed, <F> failed, <S> skipped`; step names exactly: `generated skill catalog in sync`, `generated routing table in sync`, `skill cross-references resolve`, `shell lint (changed files)` (skipped as `shell lint` with reason `shellcheck not installed`), `test: <suite path>`, `plugin manifest validation` (skipped with reason `claude not installed`), `manifests have no pinned version`.

- [ ] **Step 1: Write the failing test**

Create `tests/check-all/test-check-all.sh` with exactly this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/check-all.sh"
HOOK="$REPO_ROOT/.githooks/pre-commit"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
mkdir -p "$TEST_ROOT/home"

cleanup() {
    rm -rf "$TEST_ROOT"
}
trap cleanup EXIT

pass() {
    echo "  [PASS] $1"
}

fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

# A fake repo root with stub step scripts. Each stub exits with the code in the
# <name>.exit file next to it (default 0).
make_fixture() {
    local fix="$1" s
    mkdir -p "$fix/scripts" "$fix/tests/hooks" "$fix/.claude-plugin" "$fix/stubbin"
    cp "$SCRIPT" "$fix/scripts/check-all.sh"
    for s in generate-skill-catalog generate-routing-table check-skill-refs lint-shell; do
        printf '#!/usr/bin/env bash\nexit "$(cat "$(dirname "$0")/%s.exit" 2>/dev/null || echo 0)"\n' "$s" > "$fix/scripts/$s.sh"
    done
    printf '#!/usr/bin/env bash\nexit "$(cat "$(dirname "$0")/suite.exit" 2>/dev/null || echo 0)"\n' > "$fix/tests/hooks/test-a.sh"
    printf '{"name": "x"}\n' > "$fix/.claude-plugin/plugin.json"
    printf '{"plugins": [{"name": "x"}]}\n' > "$fix/.claude-plugin/marketplace.json"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$fix/stubbin/shellcheck"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$fix/stubbin/claude"
    chmod +x "$fix"/stubbin/* "$fix"/scripts/*.sh "$fix"/tests/hooks/test-a.sh
}

# run_check <fixture> <PATH> [cwd]  -> sets OUT and RC
run_check() {
    local fix="$1" path="$2" cwd="${3:-$1}"
    set +e
    OUT="$(cd "$cwd" && PATH="$path" HOME="$TEST_ROOT/home" bash "$fix/scripts/check-all.sh" 2>&1)"
    RC=$?
    set -e
}

assert_has() {
    if printf '%s\n' "$1" | grep -Fq -- "$2"; then
        pass "$3"
    else
        fail "$3 (missing: $2)"
    fi
}

assert_rc() {
    if [ "$RC" -eq "$1" ]; then
        pass "$2"
    else
        fail "$2 (expected exit $1, got $RC)"
    fi
}

WITH_TOOLS_PATH_SUFFIX=":/usr/bin:/bin"

echo "all steps pass"
fix="$TEST_ROOT/all-pass"
make_fixture "$fix"
run_check "$fix" "$fix/stubbin$WITH_TOOLS_PATH_SUFFIX"
assert_rc 0 "exits 0 when every step passes"
assert_has "$OUT" "PASS  generated skill catalog in sync" "catalog step passes"
assert_has "$OUT" "PASS  generated routing table in sync" "routing step passes"
assert_has "$OUT" "PASS  skill cross-references resolve" "refs step passes"
assert_has "$OUT" "PASS  shell lint (changed files)" "lint step passes"
assert_has "$OUT" "PASS  test: tests/hooks/test-a.sh" "suite step passes"
assert_has "$OUT" "PASS  plugin manifest validation" "validate step passes"
assert_has "$OUT" "PASS  manifests have no pinned version" "guard step passes"
assert_has "$OUT" "check-all: 7 passed, 0 failed, 0 skipped" "summary counts"

echo "a failing step does not stop the rest"
fix="$TEST_ROOT/one-fail"
make_fixture "$fix"
echo 1 > "$fix/scripts/generate-skill-catalog.exit"
run_check "$fix" "$fix/stubbin$WITH_TOOLS_PATH_SUFFIX"
assert_rc 1 "exits 1 when a step fails"
assert_has "$OUT" "FAIL  generated skill catalog in sync" "failing step is reported"
assert_has "$OUT" "PASS  manifests have no pinned version" "later steps still run"
assert_has "$OUT" "check-all: 6 passed, 1 failed, 0 skipped" "summary counts a failure"

echo "a failing test suite fails the run"
fix="$TEST_ROOT/suite-fail"
make_fixture "$fix"
echo 1 > "$fix/tests/hooks/suite.exit"
run_check "$fix" "$fix/stubbin$WITH_TOOLS_PATH_SUFFIX"
assert_rc 1 "exits 1 when a suite fails"
assert_has "$OUT" "FAIL  test: tests/hooks/test-a.sh" "failing suite is named"

echo "missing tools are skipped visibly"
fix="$TEST_ROOT/no-tools"
make_fixture "$fix"
run_check "$fix" "/usr/bin:/bin"
assert_rc 0 "missing tools do not fail the run"
assert_has "$OUT" "SKIP  shell lint (shellcheck not installed)" "lint skipped with a reason"
assert_has "$OUT" "SKIP  plugin manifest validation (claude not installed)" "validate skipped with a reason"
assert_has "$OUT" "check-all: 5 passed, 0 failed, 2 skipped" "summary counts skips"

echo "pinned version guard"
fix="$TEST_ROOT/pinned-plugin"
make_fixture "$fix"
printf '{"name": "x", "version": "1.0.0"}\n' > "$fix/.claude-plugin/plugin.json"
run_check "$fix" "$fix/stubbin$WITH_TOOLS_PATH_SUFFIX"
assert_rc 1 "a version in plugin.json fails the run"
assert_has "$OUT" "FAIL  manifests have no pinned version" "guard names itself for plugin.json"

fix="$TEST_ROOT/pinned-marketplace"
make_fixture "$fix"
printf '{"plugins": [{"name": "x", "version": "1.0.0"}]}\n' > "$fix/.claude-plugin/marketplace.json"
run_check "$fix" "$fix/stubbin$WITH_TOOLS_PATH_SUFFIX"
assert_rc 1 "a version in marketplace.json fails the run"
assert_has "$OUT" "FAIL  manifests have no pinned version" "guard names itself for marketplace.json"

echo "runs from a subdirectory"
fix="$TEST_ROOT/subdir"
make_fixture "$fix"
run_check "$fix" "$fix/stubbin$WITH_TOOLS_PATH_SUFFIX" "$fix/tests"
assert_rc 0 "works when invoked from a subdirectory"
assert_has "$OUT" "check-all: 7 passed, 0 failed, 0 skipped" "same steps run from a subdirectory"

echo "pre-commit hook"
if [ -x "$HOOK" ]; then pass "hook is executable"; else fail "hook is executable ($HOOK)"; fi
if grep -Fq "scripts/check-all.sh" "$HOOK" 2> /dev/null; then pass "hook calls scripts/check-all.sh"; else fail "hook calls scripts/check-all.sh"; fi

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
```

Then run: `chmod +x tests/check-all/test-check-all.sh`.

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/check-all/test-check-all.sh </dev/null`
Expected: non-zero exit. The first `cp "$SCRIPT"` fails because `scripts/check-all.sh` does not exist (`cp: .../scripts/check-all.sh: No such file or directory`); no `STATUS: PASSED`.

- [ ] **Step 3: Write the implementation**

Create `scripts/check-all.sh` with exactly this content, then `chmod +x scripts/check-all.sh`:

```bash
#!/usr/bin/env bash
#
# Run every deterministic guard in this repository and report one line per step.
#
# Usage:
#   scripts/check-all.sh
#
# Steps: the generated skill catalog and routing table are in sync, skill
# cross-references resolve, shell lint passes on changed files, the
# deterministic test suites pass, the plugin manifests validate, and neither
# manifest pins a version (a pinned version stops installs from tracking new
# commits). Every step runs even after a failure. A step whose tool is not
# installed is reported as SKIP, never hidden. Exits 1 if any step failed,
# 0 otherwise.
#
# Does not run tests that start Claude sessions (tests/claude-code other than
# test-sdd-workspace.sh, tests/explicit-skill-requests) or tests/brainstorm-server.
# To run it before every commit in your clone: git config core.hooksPath .githooks
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

PASSED=0
FAILED=0
SKIPPED=0

run_step() {
  local name="$1" out
  shift
  if out="$("$@" 2>&1 < /dev/null)"; then
    printf 'PASS  %s\n' "$name"
    PASSED=$((PASSED + 1))
  else
    printf 'FAIL  %s\n' "$name"
    printf '%s\n' "$out" | sed 's/^/      /'
    FAILED=$((FAILED + 1))
  fi
}

skip_step() {
  printf 'SKIP  %s (%s)\n' "$1" "$2"
  SKIPPED=$((SKIPPED + 1))
}

check_no_pinned_version() {
  local f bad=0
  for f in .claude-plugin/plugin.json .claude-plugin/marketplace.json; do
    [ -f "$f" ] || continue
    if grep -n '"version"' "$f"; then
      echo "$f pins a version; remove it so installs track the commit SHA" >&2
      bad=1
    fi
  done
  [ "$bad" -eq 0 ]
}

run_step "generated skill catalog in sync" bash scripts/generate-skill-catalog.sh --check
run_step "generated routing table in sync" bash scripts/generate-routing-table.sh --check
run_step "skill cross-references resolve" bash scripts/check-skill-refs.sh

if command -v shellcheck > /dev/null 2>&1; then
  run_step "shell lint (changed files)" bash scripts/lint-shell.sh
else
  skip_step "shell lint" "shellcheck not installed"
fi

for suite in tests/hooks/test-*.sh tests/shell-lint/test-*.sh tests/skill-catalog/test-*.sh \
  tests/upstream-drift/test-*.sh tests/check-all/test-*.sh tests/claude-code/test-sdd-workspace.sh; do
  [ -f "$suite" ] || continue
  run_step "test: $suite" bash "$suite"
done

if command -v claude > /dev/null 2>&1; then
  run_step "plugin manifest validation" claude plugin validate .
else
  skip_step "plugin manifest validation" "claude not installed"
fi

run_step "manifests have no pinned version" check_no_pinned_version

echo
echo "check-all: $PASSED passed, $FAILED failed, $SKIPPED skipped"
[ "$FAILED" -eq 0 ]
```

Create `.githooks/pre-commit` with exactly this content, then `chmod +x .githooks/pre-commit`:

```bash
#!/usr/bin/env bash
# Opt-in pre-commit gate. Enable in your clone with: git config core.hooksPath .githooks
exec "$(git rev-parse --show-toplevel)/scripts/check-all.sh"
```

Append this section to the end of `CONTRIBUTING.md` (leave the rest of the file unchanged):

```markdown

## Checks before you commit

Run `scripts/check-all.sh` to run every deterministic guard: the generated skill catalog and routing table, skill cross-references, shell lint on changed files, the test suites, and plugin manifest validation. To run it automatically before each commit in your clone, opt in with `git config core.hooksPath .githooks`.
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/check-all/test-check-all.sh </dev/null`
Expected: every line `[PASS]`, ending `STATUS: PASSED`, exit 0.

- [ ] **Step 5: Lint**

Run: `bash scripts/lint-shell.sh scripts/check-all.sh tests/check-all/test-check-all.sh .githooks/pre-commit tests/skill-catalog/test-generate-routing-table.sh tests/skill-catalog/test-generate-skill-catalog.sh scripts/generate-routing-table.sh; echo "exit=$?"`
Expected: `exit=0`. Fix any ShellCheck warning in the script or test (not the lint config) and re-run Steps 4 and 5.

- [ ] **Step 6: Run the real gate**

Run: `bash scripts/check-all.sh; echo "exit=$?"`
Expected: `PASS` for the catalog, routing, refs, lint, each present suite (`tests/hooks/test-session-start.sh`, `tests/shell-lint/test-lint-shell.sh`, both `tests/skill-catalog/` tests, `tests/check-all/test-check-all.sh`, `tests/claude-code/test-sdd-workspace.sh`), validate and guard steps; the last line `check-all: <N> passed, 0 failed, 0 skipped` and `exit=0`. If a step fails, report its output rather than editing the gate to hide it.

- [ ] **Step 7: Checkpoint (do not commit)**

Run: `git status --short`
Expected: modified manifests, `scripts/generate-routing-table.sh`, both skill-catalog tests, `skills/using-superpowers/SKILL.md`, `README.md`, `CONTRIBUTING.md`; untracked `scripts/check-all.sh`, `tests/check-all/`, `.githooks/`, the spec and this plan. Leave everything uncommitted and report the Step 6 output.

---

## Post-review amendments (applied after the plan was executed)

The Task 4 review reproduced a defect in the plan's code: git exports `GIT_INDEX_FILE` (and `GIT_DIR` in a linked worktree) to a pre-commit hook, and suites such as `tests/shell-lint/test-lint-shell.sh` and `tests/claude-code/test-sdd-workspace.sh` run `git init`, `git add` and `git commit` in throwaway repositories, which then write into the outer repository's index. `scripts/check-all.sh` now unsets the repository-location variables before running any step (see the spec), `tests/check-all/test-check-all.sh` gained a case proving a step sees none of them, and a case that runs `.githooks/pre-commit` for real from a subdirectory of a throwaway repository.
