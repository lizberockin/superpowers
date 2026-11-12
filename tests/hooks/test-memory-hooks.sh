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
    out="$(run_hook trigger-nudge "$(node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt")")"
    if [[ -n "$out" ]] && printf '%s' "$out" | context_of | grep -q 'superpowers:compound-memory'; then
        pass "nudges on: $prompt"
    else
        fail "expected nudge on: $prompt"
    fi
}

assert_silent() {
    local prompt="$1" out
    out="$(run_hook trigger-nudge "$(node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt")")"
    if [[ -z "$out" ]]; then
        pass "silent on: $prompt"
    else
        fail "expected silence on: $prompt"
    fi
}

echo "trigger-nudge (UserPromptSubmit)"
assert_nudge "ok that's everything, thanks"
assert_nudge "Done for now"
assert_nudge "ALL SET"
assert_silent "all settings look fine"
assert_silent "we're all set up with the dbt models, can you now refactor the staging layer and rename everything to snake_case across the whole repository please"
assert_silent "run the tests"

if [[ -z "$(run_hook trigger-nudge '')" ]]; then pass "silent on empty stdin"; else fail "expected silence on empty stdin"; fi

make_plugin_root() {
    local root="$1" s
    mkdir -p "$root/hooks"
    for s in alpha beta broken crlf loud prose zeta; do
        mkdir -p "$root/skills/$s"
    done
    cp "$HOOKS/trigger-nudge" "$root/hooks/trigger-nudge"
    cat > "$root/skills/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: fixture
---
<auto_invoke>
<trigger_phrases>
- "alpha phrase"
</trigger_phrases>
</auto_invoke>
EOF
    cat > "$root/skills/beta/SKILL.md" <<'EOF'
---
name: beta
description: fixture
---
<auto_invoke mode="consider">
<trigger_phrases>
- "beta phrase"
</trigger_phrases>
</auto_invoke>
EOF
    cat > "$root/skills/broken/SKILL.md" <<'EOF'
---
name: broken
description: fixture
---
<auto_invoke> <trigger_phrases> - "broken phrase" </trigger_phrases> </auto_invoke>
- "leak phrase"
EOF
    cat > "$root/skills/loud/SKILL.md" <<'EOF'
---
name: loud
description: fixture
---
<auto_invoke mode="loud">
<trigger_phrases>
- "loud phrase"
</trigger_phrases>
</auto_invoke>
EOF
    printf '%s\r\n' '---' 'name: crlf' 'description: fixture' '---' '<auto_invoke>' '<trigger_phrases>' '- "crlf phrase"' '</trigger_phrases>' '</auto_invoke>' > "$root/skills/crlf/SKILL.md"
    cat > "$root/skills/prose/SKILL.md" <<'EOF'
---
name: prose
description: fixture
---
To declare triggers, wrap them in <trigger_phrases> tags.
- "prose bullet"
EOF
    cat > "$root/skills/zeta/SKILL.md" <<'EOF'
---
name: zeta
description: fixture
---
<auto_invoke>
<trigger_phrases>
- "zeta phrase"
</trigger_phrases>
</auto_invoke>
EOF
}

run_root_hook() {
    local root="$1" prompt="$2"
    node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt" |
        env -i PATH="${PATH:-}" HOME="${TMPDIR:-/tmp}" bash "$root/hooks/trigger-nudge"
}

assert_root_context() {
    local root="$1" prompt="$2" skill="$3" wording="$4" out
    out="$(run_root_hook "$root" "$prompt")"
    if [[ -n "$out" ]] && printf '%s' "$out" | context_of | grep -q "superpowers:$skill" &&
        printf '%s' "$out" | context_of | grep -q "$wording"; then
        pass "'$prompt' nudges superpowers:$skill ($wording)"
    else
        fail "'$prompt' should nudge superpowers:$skill with '$wording'"
    fi
}

assert_root_silent() {
    local root="$1" prompt="$2" out
    out="$(run_root_hook "$root" "$prompt")"
    if [[ -z "$out" ]]; then
        pass "silent on: $prompt"
    else
        fail "expected silence on: $prompt"
    fi
}

echo "trigger-nudge across several skills"
plugin_root="$(mktemp -d)"
trap 'rm -rf "$plugin_root"' EXIT
make_plugin_root "$plugin_root"
assert_root_context "$plugin_root" "ok alpha phrase now" alpha "Invoke it now"
assert_root_context "$plugin_root" "BETA PHRASE" beta "Consider invoking"
assert_root_context "$plugin_root" "zeta phrase" zeta "Invoke it now"
assert_root_context "$plugin_root" "alpha phrase and beta phrase" alpha "Invoke it now"
assert_root_context "$plugin_root" "alpha phrase and beta phrase" beta "Consider invoking"
assert_root_context "$plugin_root" "loud phrase" loud "Invoke it now"
assert_root_context "$plugin_root" "crlf phrase" crlf "Invoke it now"
assert_root_silent "$plugin_root" "broken phrase"
assert_root_silent "$plugin_root" "leak phrase"
assert_root_silent "$plugin_root" "prose bullet"
assert_root_silent "$plugin_root" "nothing relevant here"
long_prompt="alpha phrase $(printf 'x%.0s' $(seq 1 130))"
assert_root_silent "$plugin_root" "$long_prompt"

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

assert_nudge_skill() {
    local prompt="$1" skill="$2" wording="$3" out
    out="$(run_hook trigger-nudge "$(node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt")")"
    if [[ -n "$out" ]] && printf '%s' "$out" | context_of | grep -q "superpowers:$skill" &&
        printf '%s' "$out" | context_of | grep -q "$wording"; then
        pass "real skills: '$prompt' nudges superpowers:$skill ($wording)"
    else
        fail "real skills: '$prompt' should nudge superpowers:$skill with '$wording'"
    fi
}

echo "every real skill that declares trigger phrases has a parseable block"
for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
    grep -q '<trigger_phrases>' "$skill_file" || continue
    skill_name="$(basename "$(dirname "$skill_file")")"
    first_phrase="$(awk '/<trigger_phrases>/{on=($0 !~ /<\/trigger_phrases>/);next} /<\/trigger_phrases>/{on=0} on && /^- "/{sub(/^- "/,"");sub(/"$/,"");print;exit}' "$skill_file")"
    if [[ -z "$first_phrase" ]]; then
        fail "$skill_name: <trigger_phrases> block has no parseable phrase lines"
        continue
    fi
    assert_nudge_skill "$first_phrase" "$skill_name" "superpowers:$skill_name"
done

echo "compound-learnings triggers"
assert_nudge_skill "it's fixed" compound-learnings "Consider invoking"
assert_nudge_skill "ok working now, thanks" compound-learnings "Consider invoking"
assert_nudge_skill "problem solved" compound-learnings "Consider invoking"
assert_nudge_skill "it's fixed, done for now" compound-memory "Invoke it now"
assert_nudge_skill "it's fixed, done for now" compound-learnings "Consider invoking"
assert_silent "that worked"

echo "hooks.json points at hooks that exist"
missing="$(node -e '
const fs = require("fs"), path = require("path");
const hooks = require(process.argv[1]).hooks;
const missing = [];
for (const groups of Object.values(hooks)) for (const g of groups) for (const h of g.hooks) {
  const m = /run-hook\.cmd"?\s+(\S+)/.exec(h.command);
  if (m && !fs.existsSync(path.join(process.argv[2], m[1]))) missing.push(m[1]);
}
console.log(missing.join(","));
' "$HOOKS/hooks.json" "$HOOKS")"
if [[ -z "$missing" ]]; then
    pass "every hook named in hooks.json exists"
else
    fail "hooks.json names missing hooks: $missing"
fi

if [[ "$FAILURES" -gt 0 ]]; then
    echo "STATUS: FAILED ($FAILURES failure(s))"
    exit 1
fi
echo "STATUS: PASSED"
