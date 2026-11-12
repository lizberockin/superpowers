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
check "override 1 requires an absolute path" grep -Fq -- 'must be an absolute path' "$CL"
check "override 1 derives the repo name from the main working tree" grep -Fq -- 'git rev-parse --git-common-dir' "$CL"
check "override 1 states the repository-root fallback" grep -Fq -- 'at the repository root' "$CL"
check "override 1 stops outside a repo with no variable" grep -Fq -- 'no store can be resolved' "$CL"
check "override 1 treats a set-but-empty variable as set" grep -Fq -- 'exits 0 (the variable is set, even if empty)' "$CL"
check "override 1 falls back to _general when git fails" grep -Fq -- 'if `git rev-parse --git-common-dir` fails' "$CL"

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
if [[ "$marker_count" -ge 16 ]]; then
    pass "at least 16 disabled-in-this-fork markers ($marker_count)"
else
    fail "expected at least 16 disabled-in-this-fork markers, found $marker_count"
fi
marked() {
    grep -F -- "$1" "$CL" | grep -qi 'disabled in this fork'
}
for anchor in \
    'Session history — an automatic probe in Full mode' \
    '**Then** run the internal session-history discovery' \
    '4. **Vocabulary capture (update-only)**' \
    '5. **Read-only discoverability check**' \
    'routes to Full Mode with its automatic session-history probe' \
    'run session history as an automatic probe' \
    'defaulting to **Full mode** with the automatic session-history probe' \
    'including the automatic session-history probe (Phase 1 step 4' \
    '**`CONCEPTS.md`** — ' \
    '**A project instruction file** (AGENTS.md or CLAUDE.md)' \
    '**WAIT for all Phase 1 inputs to complete before proceeding**'; do
    check "marked disabled: $anchor" marked "$anchor"
done

echo "compound-learnings: paths use the resolved store"
check "no literal mkdir -p docs/solutions" bash -c '! grep -Fq -- "mkdir -p docs/solutions" "$1"' _ "$CL"
check "write step uses SOLUTIONS_DIR" bash -c 'grep -F -- "Write the file: either the updated existing doc" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "directory step uses SOLUTIONS_DIR" bash -c 'grep -F -- "Create directory if needed" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "collision check uses SOLUTIONS_DIR" bash -c 'grep -F -- "the exact proposed" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "fresh glob uses SOLUTIONS_DIR" bash -c 'grep -F -- "glob the resolved store" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "related-docs search uses SOLUTIONS_DIR" grep -Fq -- 'Searches the resolved store (`$SOLUTIONS_DIR`)' "$CL"
check "category narrowing uses SOLUTIONS_DIR" grep -Fq -- 'matching `$SOLUTIONS_DIR/<category>/` directory' "$CL"
check "no literal docs/solutions category narrowing" bash -c '! grep -Fq -- "matching \`docs/solutions/<category>/\`" "$1"' _ "$CL"
check "subagents receive the resolved store" bash -c 'grep -F -- "into every Phase 1 subagent prompt" "$1" | grep -Fq -- "\$SOLUTIONS_DIR"' _ "$CL"
check "subagents receive the no-patient-data rule" bash -c 'grep -F -- "into every Phase 1 subagent prompt" "$1" | grep -Fq -- "Fork Override 5"' _ "$CL"
check "write step redacts per Fork Override 5" bash -c 'grep -F -- "Write the file: either the updated existing doc" "$1" | grep -Fq -- "Fork Override 5"' _ "$CL"
check "success output note skips disabled lines" grep -Fq -- 'skip the Session History, CONCEPTS.md and instruction-file' "$CL"

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

echo "systematic-debugging: consult step"
check "has the known-solution paragraph" grep -Fq -- '**Check for a known solution first.**' "$SD"
check "names SUPERPOWERS_SOLUTIONS_ROOT" grep -Fq -- 'SUPERPOWERS_SOLUTIONS_ROOT' "$SD"
consult_line="$(grep -n -F -- '**Check for a known solution first.**' "$SD" | head -n 1 | cut -d: -f1 || true)"
first_step_line="$(grep -n -F -- '1. **Read Error Messages Carefully**' "$SD" | head -n 1 | cut -d: -f1 || true)"
if [[ -n "$consult_line" && -n "$first_step_line" && "$consult_line" -lt "$first_step_line" ]]; then
    pass "the consult paragraph comes before the numbered steps"
else
    fail "the consult paragraph must come before '1. **Read Error Messages Carefully**' (consult=${consult_line:-none}, step=${first_step_line:-none})"
fi
check "treats a match as evidence, not a fix" grep -Fq -- 'evidence to verify' "$SD"
check "derives the repo name from the main working tree" grep -Fq -- 'git rev-parse --git-common-dir' "$SD"
check "consult step falls back to _general when git fails" grep -Fq -- '`_general` if that command fails' "$SD"
check "skips silently when the store is missing" grep -Fq -- 'If the directory does not exist, skip this.' "$SD"

echo "both skills use the same variable name"
cl_vars="$(grep -o 'SUPERPOWERS_[A-Z_]*' "$CL" | sort -u | tr '\n' ' ' || true)"
sd_vars="$(grep -o 'SUPERPOWERS_[A-Z_]*' "$SD" | sort -u | tr '\n' ' ' || true)"
if [[ -n "$cl_vars" && "$cl_vars" == "$sd_vars" ]]; then
    pass "same SUPERPOWERS_* variables in both skills ($cl_vars)"
else
    fail "variable names differ: compound-learnings=[$cl_vars] systematic-debugging=[$sd_vars]"
fi

echo "skill references still resolve"
check "check-skill-refs.sh passes" bash "$REPO_ROOT/scripts/check-skill-refs.sh"

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi

echo "STATUS: PASSED"
