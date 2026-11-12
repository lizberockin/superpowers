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
    write hooks/h.sh fork2
    g add -A
    g commit -q -m fork2
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
assert_has "$out" "== adopt upstream-only skills ==" "adopt block is present"
assert_has "$out" "git diff --stat $base_full upstream/main -- skills/s-both" "compare command for a both-changed skill"
assert_has "$out" "git diff --stat $base_full upstream/main -- README.md" "compare command for a both-changed top-level file"
if printf '%s\n' "$out" | section_of "adopt upstream-only skills" | grep -Fq "s-both"; then
    fail "both-changed unit must not appear in the adopt block"
else
    pass "both-changed unit absent from the adopt block"
fi
for other in scripts .claude-plugin; do
    if printf '%s\n' "$out" | section_of "adopt upstream-only skills" | grep -Fq -- "-- $other"; then
        fail "upstream-only other path $other must not appear in the adopt block"
    else
        pass "upstream-only other path $other absent from the adopt block"
    fi
done

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

echo "header, summary and tip"
base_short="$(g rev-parse --short "$(g merge-base HEAD upstream/main)")"
assert_has "$out" "merge-base: $base_short | HEAD is 2 ahead, 1 behind upstream/main" "header shows merge-base and ahead/behind"
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

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
