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
# git exports these to hooks; suites that build throwaway repos must not inherit them.
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE GIT_PREFIX GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_NAMESPACE

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
