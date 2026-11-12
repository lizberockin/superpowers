#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
HOOKS="$REPO_ROOT/hooks"

FAILURES=0

pass() { echo "  [PASS] $1"; }
fail() {
    echo "  [FAIL] $1"
    FAILURES=$((FAILURES + 1))
}

run_hook() {
    local script="$1" payload="$2"
    printf '%s' "$payload" | env -i PATH="${PATH:-}" HOME="${TMPDIR:-/tmp}" CLAUDE_PLUGIN_ROOT="$REPO_ROOT" bash "$HOOKS/$script"
}

context_of() {
    node -e 'let s="";process.stdin.on("data",d=>s+=d).on("end",()=>{const o=JSON.parse(s);console.log(o.hookSpecificOutput.additionalContext)})'
}

assert_nudge() {
    local prompt="$1" out
    out="$(run_hook wrap-up-nudge "$(node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt")")"
    if [[ -n "$out" ]] && printf '%s' "$out" | context_of | grep -q 'superpowers:compound-memory'; then
        pass "nudges on: $prompt"
    else
        fail "expected nudge on: $prompt"
    fi
}

assert_silent() {
    local prompt="$1" out
    out="$(run_hook wrap-up-nudge "$(node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt")")"
    if [[ -z "$out" ]]; then
        pass "silent on: $prompt"
    else
        fail "expected silence on: $prompt"
    fi
}

echo "wrap-up-nudge (UserPromptSubmit)"
assert_nudge "ok that's everything, thanks"
assert_nudge "Done for now"
assert_nudge "ALL SET"
assert_silent "all settings look fine"
assert_silent "we're all set up with the dbt models, can you now refactor the staging layer and rename everything to snake_case across the whole repository please"
assert_silent "run the tests"

if [[ -z "$(run_hook wrap-up-nudge '')" ]]; then pass "silent on empty stdin"; else fail "expected silence on empty stdin"; fi

echo "pre-compact (PreCompact)"
if run_hook pre-compact '{"trigger":"auto"}' | grep -q 'Unsaved memory candidates'; then
    pass "asks the summary to keep unsaved memory candidates"
else
    fail "pre-compact output missing instructions"
fi

echo "session-start compaction nudge"
if run_hook session-start '{"source":"compact"}' | context_of | grep -q 'Context was just compacted'; then
    pass "source=compact adds the nudge"
else
    fail "source=compact missing the nudge"
fi
for src in startup clear; do
    if run_hook session-start "{\"source\":\"$src\"}" | context_of | grep -q 'Context was just compacted'; then
        fail "source=$src must not add the nudge"
    else
        pass "source=$src has no nudge"
    fi
done

echo "hooks.json"
if node -e '
const h=require(process.argv[1]).hooks;
for (const e of ["SessionStart","UserPromptSubmit","PreCompact"]) if(!h[e]) { console.error("missing "+e); process.exit(1); }
' "$HOOKS/hooks.json"; then
    pass "registers SessionStart, UserPromptSubmit, PreCompact"
else
    fail "hooks.json missing an event"
fi

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi
echo "STATUS: PASSED"
