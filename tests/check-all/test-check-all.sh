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

# run_check_git_env <fixture> <PATH>  -> like run_check, with git hook variables exported
run_check_git_env() {
    local fix="$1" path="$2"
    set +e
    OUT="$(
        cd "$fix"
        export GIT_DIR=/nonexistent/gitdir GIT_WORK_TREE=/nonexistent/worktree \
            GIT_INDEX_FILE=/nonexistent/index GIT_PREFIX=sub/ GIT_COMMON_DIR=/nonexistent/common \
            GIT_OBJECT_DIRECTORY=/nonexistent/objects GIT_ALTERNATE_OBJECT_DIRECTORIES=/nonexistent/alt \
            GIT_NAMESPACE=bogus
        PATH="$path" HOME="$TEST_ROOT/home" bash "$fix/scripts/check-all.sh" 2>&1
    )"
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
mkdir -p "$TEST_ROOT/minbin"
for tool in bash cat sed grep dirname; do
    real="$(command -v "$tool")" || { echo "cannot find $tool for minbin" >&2; exit 1; }
    ln -s "$real" "$TEST_ROOT/minbin/$tool"
done
run_check "$fix" "$TEST_ROOT/minbin"
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

echo "git hook environment is scrubbed"
fix="$TEST_ROOT/git-env"
make_fixture "$fix"
cat > "$fix/tests/hooks/test-env.sh" << 'EOF'
#!/usr/bin/env bash
for v in GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE; do
  if [ -n "${!v+x}" ]; then
    echo "$v leaked into the suite" >&2
    exit 1
  fi
done
exit 0
EOF
chmod +x "$fix/tests/hooks/test-env.sh"
run_check_git_env "$fix" "$fix/stubbin$WITH_TOOLS_PATH_SUFFIX"
assert_rc 0 "exits 0 when git hook variables are inherited"
assert_has "$OUT" "PASS  test: tests/hooks/test-env.sh" "suites do not see GIT_* variables"

echo "hook runs for real"
repo="$TEST_ROOT/hook-repo"
make_fixture "$repo"
git init -q -b main "$repo"
git -C "$repo" config user.name "Test"
git -C "$repo" config user.email "test@example.com"
mkdir -p "$repo/.githooks" "$repo/sub"
cp "$HOOK" "$repo/.githooks/pre-commit"
set +e
OUT="$(cd "$repo/sub" && PATH="$repo/stubbin:/usr/bin:/bin" HOME="$TEST_ROOT/home" bash "$repo/.githooks/pre-commit" 2>&1)"
RC=$?
set -e
assert_rc 0 "hook exits 0 from a subdirectory of a real repo"
assert_has "$OUT" "check-all: 7 passed, 0 failed, 0 skipped" "hook runs every step"

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
