# Upstream Drift Triage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `scripts/upstream-drift.sh`, a read-only report that classifies every skill and every other top-level path as untouched, in-sync, fork-only, upstream-only or both-changed against upstream, and prints the commands to adopt upstream-only units.

**Architecture:** One self-contained bash script that compares git tree or blob hashes at three refs (merge-base, upstream, HEAD) for each unit, classifies with a five-way rule, and prints grouped lines plus an adoption block. Tests build a throwaway git repository with base, upstream and fork histories and assert on the script's text output.

**Tech Stack:** bash (3.2-compatible: no associative arrays), git, awk, sed; tests in the style of `tests/skill-catalog/test-generate-routing-table.sh`.

Spec: `docs/specs/2026-11-12-upstream-drift-triage-design.md`.

## Global Constraints

- Read-only: never write to the working tree, the index or git config; no network calls (no `git fetch`).
- Bash only, self-contained, no shared library; follow `scripts/check-skill-refs.sh` conventions (usage header comment, `set -euo pipefail`, `die()` helper).
- Default upstream ref is `upstream/main`; it is the only optional argument.
- Exit 0 on success (it is a report, not a check); non-zero with a message on a missing ref, a missing merge-base, or a non-repository.
- Missing-ref message must hint `git fetch upstream`.
- Labels are exactly: `untouched`, `in-sync`, `fork-only`, `upstream-only`, `both-changed`.
- `untouched` units are counted but not listed. No state file. No change to any skill.
- Per the user's standing rule, do not commit unless the user asks. Where the usual plan format has a commit step, the last step of each task is a checkpoint that leaves changes uncommitted.
- Work on branch `feat/upstream-drift-triage` in `$HOME/code/superpowers`. Run all commands from that directory.

---

### Task 1: Classification engine, with adoption and compare commands

**Files:**
- Create: `tests/upstream-drift/test-upstream-drift.sh`
- Create: `scripts/upstream-drift.sh`

**Interfaces:**
- Produces (script output, used by later tasks' tests): two sections headed exactly `== skills ==` and `== other paths ==`; each listed unit on its own line formatted `printf '%-14s %s\n' <label> <path>`, grouped in the order `upstream-only`, `both-changed`, `fork-only`, `in-sync`; after the sections, a block headed `== adopt upstream-only ==` and a block headed `== compare both-changed ==`.
- Produces (test helpers used by later tasks): `build_fixture`, `run_drift`, `section_of`, `assert_label`, `pass`, `fail`, variables `TEST_ROOT`, `FIX`, `SCRIPT`.

- [ ] **Step 1: Write the failing test file**

Create `tests/upstream-drift/test-upstream-drift.sh` with exactly this content:

```bash
#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT="$REPO_ROOT/scripts/upstream-drift.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"
FIX="$TEST_ROOT/repo"
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

g() {
    git -C "$FIX" "$@"
}

write() {
    mkdir -p "$(dirname "$FIX/$1")"
    printf '%s\n' "$2" > "$FIX/$1"
}

# Base, upstream and fork histories. Resulting classification:
#   skills:      s-untouched untouched, s-insync in-sync, s-fork + s-newfork fork-only,
#                s-up + s-newup + s-updeleted upstream-only, s-both both-changed
#   other paths: docs untouched, hooks fork-only, scripts + .claude-plugin upstream-only,
#                README.md both-changed
build_fixture() {
    mkdir -p "$FIX"
    g init -q -b main
    g config user.email tester@example.com
    g config user.name tester
    local s
    for s in untouched insync fork up both updeleted; do
        write "skills/s-$s/SKILL.md" base
    done
    write hooks/h.sh base
    write scripts/x.sh base
    write docs/d.md base
    write README.md base
    write .claude-plugin/plugin.json '{"version": "6.3.0"}'
    g add -A
    g commit -q -m base

    g checkout -q -b up
    write skills/s-insync/SKILL.md shared
    write skills/s-up/SKILL.md up
    write skills/s-both/SKILL.md up
    g rm -q -r skills/s-updeleted
    write skills/s-newup/SKILL.md up
    write scripts/x.sh up
    write README.md up
    write .claude-plugin/plugin.json '{"version": "7.0.2"}'
    g add -A
    g commit -q -m upstream
    g update-ref refs/remotes/upstream/main "$(g rev-parse HEAD)"

    g checkout -q main
    write skills/s-insync/SKILL.md shared
    write skills/s-fork/SKILL.md fork
    write skills/s-both/SKILL.md fork
    write skills/s-newfork/SKILL.md fork
    write hooks/h.sh fork
    write README.md fork
    g add -A
    g commit -q -m fork
}

run_drift() {
    (cd "$FIX" && HOME="$TEST_ROOT/home" bash "$SCRIPT" "$@")
}

section_of() {
    awk -v s="== $1 ==" '/^== /{cur=$0} cur==s'
}

# assert_label <output> <section> <label> <path>
assert_label() {
    local expected
    expected="$(printf '%-14s %s' "$3" "$4")"
    if printf '%s\n' "$1" | section_of "$2" | grep -Fxq "$expected"; then
        pass "$2: $4 is $3"
    else
        fail "$2: expected '$expected'"
    fi
}

# assert_absent <output> <section> <path>
assert_absent() {
    if printf '%s\n' "$1" | section_of "$2" | grep -Fq " $3"; then
        fail "$2: $3 should not be listed"
    else
        pass "$2: $3 not listed"
    fi
}

# assert_has <output> <fixed-string> <description>
assert_has() {
    if printf '%s\n' "$1" | grep -Fq -- "$2"; then
        pass "$3"
    else
        fail "$3 (missing: $2)"
    fi
}

echo "classification"
build_fixture
out="$(run_drift)"

assert_label "$out" skills upstream-only skills/s-up
assert_label "$out" skills upstream-only skills/s-newup
assert_label "$out" skills upstream-only skills/s-updeleted
assert_label "$out" skills both-changed skills/s-both
assert_label "$out" skills fork-only skills/s-fork
assert_label "$out" skills fork-only skills/s-newfork
assert_label "$out" skills in-sync skills/s-insync
assert_absent "$out" skills skills/s-untouched

assert_label "$out" "other paths" both-changed README.md
assert_label "$out" "other paths" fork-only hooks
assert_label "$out" "other paths" upstream-only scripts
assert_label "$out" "other paths" upstream-only .claude-plugin
assert_absent "$out" "other paths" docs
assert_absent "$out" "other paths" skills

echo "adoption and compare commands"
assert_has "$out" "git rm -r -q --ignore-unmatch skills/s-up && git checkout upstream/main -- skills/s-up" "adopt command for a changed upstream skill"
assert_has "$out" "git rm -r -q --ignore-unmatch skills/s-newup && git checkout upstream/main -- skills/s-newup" "adopt command for a skill added upstream"
assert_has "$out" "git rm -r -q skills/s-updeleted" "remove command for a skill upstream deleted"
base_full="$(g merge-base HEAD upstream/main)"
assert_has "$out" "== adopt upstream-only ==" "adopt block is present"
assert_has "$out" "git diff --stat $base_full upstream/main -- skills/s-both" "compare command for a both-changed skill"
assert_has "$out" "git diff --stat $base_full upstream/main -- README.md" "compare command for a both-changed top-level file"
if printf '%s\n' "$out" | section_of "adopt upstream-only" | grep -Fq "s-both"; then
    fail "both-changed unit must not appear in the adopt block"
else
    pass "both-changed unit absent from the adopt block"
fi

echo "group order"
order="$(printf '%s\n' "$out" | section_of skills | awk '$1 == "upstream-only" || $1 == "both-changed" || $1 == "fork-only" || $1 == "in-sync" { print $1 }' | uniq | tr '\n' ' ')"
if [ "$order" = "upstream-only both-changed fork-only in-sync " ]; then
    pass "labels are grouped in the documented order"
else
    fail "unexpected label order: $order"
fi

echo "non-default ref"
out_ref="$(run_drift refs/remotes/upstream/main)"
assert_has "$out_ref" "git checkout refs/remotes/upstream/main -- skills/s-up" "adopt command uses the ref that was passed"

echo "robustness"
out_sub="$(cd "$FIX/scripts" && HOME="$TEST_ROOT/home" bash "$SCRIPT")"
assert_label "$out_sub" skills upstream-only skills/s-up
assert_label "$out_sub" "other paths" upstream-only scripts

uni="$TEST_ROOT/unicode"
mkdir -p "$uni/skills/plain"
git -C "$uni" init -q -b main
git -C "$uni" config user.email tester@example.com
git -C "$uni" config user.name tester
echo base > "$uni/skills/plain/SKILL.md"
git -C "$uni" add -A
git -C "$uni" commit -q -m base
git -C "$uni" checkout -q -b up
mkdir -p "$uni/skills/café"
echo up > "$uni/skills/café/SKILL.md"
git -C "$uni" add -A
git -C "$uni" commit -q -m upstream
git -C "$uni" update-ref refs/remotes/upstream/main "$(git -C "$uni" rev-parse HEAD)"
git -C "$uni" checkout -q main
out_uni="$(cd "$uni" && HOME="$TEST_ROOT/home" bash "$SCRIPT")"
assert_label "$out_uni" skills upstream-only "skills/café"

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `bash tests/upstream-drift/test-upstream-drift.sh`
Expected: non-zero exit. The output contains `scripts/upstream-drift.sh: No such file or directory` (the script does not exist yet) and no `STATUS: PASSED`.

- [ ] **Step 3: Write the minimal implementation**

Create `scripts/upstream-drift.sh` with exactly this content, then `chmod +x scripts/upstream-drift.sh`:

```bash
#!/usr/bin/env bash
#
# Classify every skill, and every other top-level path, against upstream so
# syncing the fork becomes a short list of per-unit decisions.
#
# Usage:
#   scripts/upstream-drift.sh [upstream-ref]
#
# upstream-ref defaults to upstream/main. For each unit the script compares the
# git tree (or blob) hash at the merge-base, at upstream and at HEAD, and
# prints one label per unit:
#   untouched      same at all three (counted, not listed)
#   in-sync        upstream and HEAD match, merge-base differs
#   fork-only      only HEAD changed
#   upstream-only  only upstream changed; the adoption command is printed
#   both-changed   all three differ; diff-stat commands are printed
#
# Committed state only. Read-only: never writes to the working tree, the index
# or git config, and makes no network calls. Run `git fetch upstream` first
# for fresh results.
set -euo pipefail

UPSTREAM="${1:-upstream/main}"
# ls-tree paths are relative to the working directory; the unit names must be repo-root-relative.
cd "$(git rev-parse --show-toplevel)"
BASE="$(git merge-base HEAD "$UPSTREAM")"

hash_at() {
  git rev-parse --verify --quiet "$1:$2" 2>/dev/null || echo absent
}

skills_at() {
  git -c core.quotePath=false ls-tree --name-only "$1" skills/ 2>/dev/null || true
}

others_at() {
  git -c core.quotePath=false ls-tree --name-only "$1" | grep -vx 'skills' || true
}

union_of() {
  { "$1" "$BASE"; "$1" "$UPSTREAM"; "$1" HEAD; } | sort -u
}

classify() {
  local b="$1" u="$2" h="$3"
  if [ "$u" = "$h" ]; then
    if [ "$b" = "$u" ]; then echo untouched; else echo in-sync; fi
  elif [ "$b" = "$u" ]; then
    echo fork-only
  elif [ "$b" = "$h" ]; then
    echo upstream-only
  else
    echo both-changed
  fi
}

# Prints "label<TAB>path<TAB>upstream-hash" for each path in the newline list $1.
classify_all() {
  local path b u h
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    b="$(hash_at "$BASE" "$path")"
    u="$(hash_at "$UPSTREAM" "$path")"
    h="$(hash_at HEAD "$path")"
    printf '%s\t%s\t%s\n' "$(classify "$b" "$u" "$h")" "$path" "$u"
  done <<< "$1"
}

print_section() {
  local label
  echo
  echo "== $1 =="
  for label in upstream-only both-changed fork-only in-sync; do
    printf '%s\n' "$2" | awk -F'\t' -v l="$label" '$1 == l { printf "%-14s %s\n", l, $2 }'
  done
}

print_adopt() {
  echo
  echo "== adopt upstream-only =="
  printf '%s\n' "$@" | awk -F'\t' -v ref="$UPSTREAM" '
    $1 == "upstream-only" && $3 == "absent" { printf "git rm -r -q %s\n", $2 }
    $1 == "upstream-only" && $3 != "absent" { printf "git rm -r -q --ignore-unmatch %s && git checkout %s -- %s\n", $2, ref, $2 }'
}

print_compare() {
  echo
  echo "== compare both-changed =="
  printf '%s\n' "$@" | awk -F'\t' -v base="$BASE" -v ref="$UPSTREAM" '
    $1 == "both-changed" { printf "git diff --stat %s %s -- %s ; git diff --stat %s HEAD -- %s\n", base, ref, $2, base, $2 }'
}

skill_rows="$(classify_all "$(union_of skills_at)")"
other_rows="$(classify_all "$(union_of others_at)")"

print_section skills "$skill_rows"
print_section "other paths" "$other_rows"
print_adopt "$skill_rows" "$other_rows"
print_compare "$skill_rows" "$other_rows"
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `bash tests/upstream-drift/test-upstream-drift.sh`
Expected: every line `[PASS]`, ending with `STATUS: PASSED`. If a label assertion fails, print the script's output with `cd` into a rebuilt fixture rather than editing the assertion.

- [ ] **Step 5: Checkpoint (do not commit)**

Run: `git status --short`
Expected: `scripts/upstream-drift.sh` and `tests/upstream-drift/` shown as untracked alongside the spec, plan and ideation docs. Leave everything uncommitted unless the user asks.

---

### Task 2: Header, summary counts and the rerere tip, with a read-only guarantee

**Files:**
- Modify: `scripts/upstream-drift.sh` (add functions; replace the final block of calls)
- Modify: `tests/upstream-drift/test-upstream-drift.sh` (insert tests above the final `if [[ "$FAILURES" -gt 0 ]]` block)

**Interfaces:**
- Consumes: `classify_all`, `print_section`, `print_adopt`, `print_compare`, `skill_rows`, `other_rows`, `BASE`, `UPSTREAM` from Task 1; test helpers `build_fixture`, `run_drift`, `assert_has`, `pass`, `fail`, `g`, `out` from Task 1.
- Produces: header lines `merge-base: <short-sha> | HEAD is <N> ahead, <M> behind <upstream-ref>` and `plugin version: upstream <v> | HEAD <v>` printed before the sections; a `== summary ==` block with lines `skills: untouched=N in-sync=N fork-only=N upstream-only=N both-changed=N` and `other paths: ...` (same shape); a final line `tip: git config rerere.enabled true` printed only when `rerere.enabled` is unset.

- [ ] **Step 1: Write the failing tests**

Insert this block in `tests/upstream-drift/test-upstream-drift.sh` immediately above the line `if [[ "$FAILURES" -gt 0 ]]; then`:

```bash
echo "header, summary and tip"
base_short="$(g rev-parse --short "$(g merge-base HEAD upstream/main)")"
assert_has "$out" "merge-base: $base_short | HEAD is 1 ahead, 1 behind upstream/main" "header shows merge-base and ahead/behind"
assert_has "$out" "plugin version: upstream 7.0.2 | HEAD 6.3.0" "header shows plugin versions"
assert_has "$out" "skills: untouched=1 in-sync=1 fork-only=2 upstream-only=3 both-changed=1" "skills summary counts"
assert_has "$out" "other paths: untouched=1 in-sync=0 fork-only=1 upstream-only=2 both-changed=1" "other paths summary counts"
assert_has "$out" "tip: git config rerere.enabled true" "rerere tip shown when unset"
g config rerere.enabled true
out_rerere="$(run_drift)"
if printf '%s\n' "$out_rerere" | grep -Fq "rerere"; then
    fail "rerere tip should disappear once enabled"
else
    pass "rerere tip hidden when enabled"
fi
g config --unset rerere.enabled

echo "read-only"
before_status="$(g status --porcelain)"
before_config="$(g config --local --list)"
run_drift > /dev/null
if [ "$(g status --porcelain)" = "$before_status" ]; then pass "working tree unchanged"; else fail "working tree changed"; fi
if [ "$(g config --local --list)" = "$before_config" ]; then pass "git config unchanged"; else fail "git config changed"; fi

```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/upstream-drift/test-upstream-drift.sh`
Expected: Task 1's assertions still `[PASS]`; the new header, summary and tip assertions `[FAIL]` (for example `[FAIL] header shows merge-base and ahead/behind (missing: merge-base: ...)`); ends with `STATUS: FAILED`.

- [ ] **Step 3: Write the implementation**

In `scripts/upstream-drift.sh`, insert these functions immediately above the line `skill_rows="$(classify_all "$(union_of skills_at)")"`:

```bash
version_at() {
  git show "$1:.claude-plugin/plugin.json" 2>/dev/null |
    sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' | head -n 1 || true
}

print_header() {
  local ahead behind up_v head_v
  ahead="$(git rev-list --count "$UPSTREAM..HEAD")"
  behind="$(git rev-list --count "HEAD..$UPSTREAM")"
  up_v="$(version_at "$UPSTREAM")"
  head_v="$(version_at HEAD)"
  echo "merge-base: $(git rev-parse --short "$BASE") | HEAD is $ahead ahead, $behind behind $UPSTREAM"
  echo "plugin version: upstream ${up_v:-unknown} | HEAD ${head_v:-unknown}"
}

count_line() {
  local label
  printf '%s:' "$1"
  for label in untouched in-sync fork-only upstream-only both-changed; do
    printf ' %s=%s' "$label" "$(printf '%s\n' "$2" | awk -F'\t' -v l="$label" '$1 == l { n++ } END { print n + 0 }')"
  done
  echo
}

print_summary() {
  echo
  echo "== summary =="
  count_line skills "$skill_rows"
  count_line "other paths" "$other_rows"
}

print_tip() {
  if [ -z "$(git config --get rerere.enabled || true)" ]; then
    echo
    echo "tip: git config rerere.enabled true"
  fi
}

```

Then replace the final block of calls (the four `print_*` lines after the two `*_rows=` assignments) so the end of the file reads:

```bash
skill_rows="$(classify_all "$(union_of skills_at)")"
other_rows="$(classify_all "$(union_of others_at)")"

print_header
print_section skills "$skill_rows"
print_section "other paths" "$other_rows"
print_summary
print_adopt "$skill_rows" "$other_rows"
print_compare "$skill_rows" "$other_rows"
print_tip
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/upstream-drift/test-upstream-drift.sh`
Expected: all `[PASS]`, ending with `STATUS: PASSED`.

- [ ] **Step 5: Checkpoint (do not commit)**

Run: `git status --short`
Expected: unchanged from Task 1's checkpoint (still uncommitted). Leave changes in place.

---

### Task 3: Errors, `--help`, lint, and a first run on the real fork

**Files:**
- Modify: `scripts/upstream-drift.sh` (replace the top of the file after the header comment)
- Modify: `tests/upstream-drift/test-upstream-drift.sh` (insert tests above the final `if [[ "$FAILURES" -gt 0 ]]` block)

**Interfaces:**
- Consumes: everything from Tasks 1 and 2; test helpers `run_drift`, `assert_has`, `pass`, `fail`, `g`, `TEST_ROOT`, `SCRIPT`.
- Produces: `usage()` (prints the header comment), `die()`; exit 0 for `-h`/`--help`; exit 1 with `error: ...` on stderr for a non-repository, an unresolvable ref, or no merge-base.

- [ ] **Step 1: Write the failing tests**

Insert this block above the line `if [[ "$FAILURES" -gt 0 ]]; then`:

```bash
echo "errors and help"
if help_out="$(run_drift --help 2>&1)"; then pass "--help exits 0"; else fail "--help should exit 0"; fi
assert_has "$help_out" "Usage:" "--help prints the usage header"

if err="$(run_drift no-such-ref 2>&1)"; then fail "missing ref should exit non-zero"; else pass "missing ref exits non-zero"; fi
assert_has "$err" "no-such-ref" "missing ref message names the ref"
assert_has "$err" "git fetch upstream" "missing ref message hints git fetch upstream"

plain="$TEST_ROOT/plain"
mkdir -p "$plain"
if err="$(cd "$plain" && HOME="$TEST_ROOT/home" GIT_CEILING_DIRECTORIES="$TEST_ROOT" bash "$SCRIPT" 2>&1)"; then
    fail "outside a repository should exit non-zero"
else
    pass "outside a repository exits non-zero"
fi
assert_has "$err" "not inside a git repository" "non-repository message"

lone="$TEST_ROOT/lone"
mkdir -p "$lone"
git -C "$lone" init -q -b main
git -C "$lone" config user.email tester@example.com
git -C "$lone" config user.name tester
echo a > "$lone/a"
git -C "$lone" add a
git -C "$lone" commit -q -m a
git -C "$lone" checkout -q --orphan other
git -C "$lone" rm -rf -q .
echo b > "$lone/b"
git -C "$lone" add b
git -C "$lone" commit -q -m b
if err="$(cd "$lone" && HOME="$TEST_ROOT/home" bash "$SCRIPT" main 2>&1)"; then
    fail "unrelated histories should exit non-zero"
else
    pass "unrelated histories exit non-zero"
fi
assert_has "$err" "no merge-base" "no merge-base message"

```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/upstream-drift/test-upstream-drift.sh`
Expected: earlier assertions `[PASS]`; `[FAIL] --help should exit 0` or `[FAIL] --help prints the usage header`, `[FAIL] missing ref message hints git fetch upstream`, `[FAIL] non-repository message` and `[FAIL] no merge-base message`; ends with `STATUS: FAILED`.

- [ ] **Step 3: Write the implementation**

In `scripts/upstream-drift.sh`, replace these three lines (the `UPSTREAM=` assignment, the `cd` line and the `BASE=` assignment directly below `set -euo pipefail`):

```bash
UPSTREAM="${1:-upstream/main}"
# ls-tree paths are relative to the working directory; the unit names must be repo-root-relative.
cd "$(git rev-parse --show-toplevel)"
BASE="$(git merge-base HEAD "$UPSTREAM")"
```

with:

```bash
usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

die() {
  echo "error: $*" >&2
  exit 1
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

UPSTREAM="${1:-upstream/main}"

git rev-parse --git-dir > /dev/null 2>&1 || die "not inside a git repository"
git rev-parse --verify --quiet "${UPSTREAM}^{commit}" > /dev/null ||
  die "upstream ref '$UPSTREAM' not found (try: git fetch upstream)"
# ls-tree paths are relative to the working directory; the unit names must be repo-root-relative.
cd "$(git rev-parse --show-toplevel)"
BASE="$(git merge-base HEAD "$UPSTREAM")" ||
  die "no merge-base between HEAD and $UPSTREAM"
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/upstream-drift/test-upstream-drift.sh`
Expected: all `[PASS]`, ending with `STATUS: PASSED`.

- [ ] **Step 5: Lint**

Run: `bash scripts/lint-shell.sh scripts/upstream-drift.sh tests/upstream-drift/test-upstream-drift.sh; echo "exit=$?"`
Expected: `Linting 2 shell files` and `exit=0`. If ShellCheck reports a warning, fix the script or test (not the lint config) and re-run Steps 4 and 5.

- [ ] **Step 6: First run on the real fork (report only, no edits)**

Run these from `$HOME/code/superpowers` on branch `feat/upstream-drift-triage`:

```bash
before="$(git status --short)"
bash scripts/upstream-drift.sh
[ "$(git status --short)" = "$before" ] && echo "read-only: ok"
```

Expected: a header showing 83 ahead and 59 behind `upstream/main` (merge-base `d884ae0`) and plugin versions `upstream 7.0.2 | HEAD 6.3.0`; six `upstream-only` skills (`receiving-code-review`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `verification-before-completion`, `diagnosing-superpowers`) and nine `both-changed` skills (`brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `requesting-code-review`, `subagent-driven-development`, `using-superpowers`, `writing-plans`, `writing-skills`); then `read-only: ok`. If the numbers differ, report the actual output rather than adjusting the script.

Then read the `description:` lines and opening sections of `skills/diagnosing-bugs/SKILL.md` and `skills/systematic-debugging/SKILL.md` and report how they overlap. Do not edit any skill.

- [ ] **Step 7: Checkpoint (do not commit)**

Run: `git status --short`
Expected: new files untracked (script, test directory, spec, plan, ideation doc); no modified tracked files. Report the first-run results and stop; the user decides whether to commit and what to adopt.

---

## Post-review amendments (applied after the plan was executed)

The code blocks above are the plan as first written, amended once after the Task 1 review (repo-root `cd`, `core.quotePath=false`, tighter tests). The final whole-branch review led to three further changes that are not reflected in the code blocks:

- The adopt block lists upstream-only skills only: `print_adopt "$skill_rows"`, heading `== adopt upstream-only skills ==`; upstream-only other paths are listed without commands. The spec was amended to match.
- The test fixture gained a second fork commit (touching `hooks/h.sh`) so the header assertion reads `HEAD is 2 ahead, 1 behind upstream/main` and pins the ahead/behind direction.
- `tests/upstream-drift/test-upstream-drift.sh` is executable, like its siblings in `tests/skill-catalog/`.
