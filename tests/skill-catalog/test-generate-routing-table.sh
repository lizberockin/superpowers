#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATOR="$REPO_ROOT/scripts/generate-routing-table.sh"

FAILURES=0
TEST_ROOT="$(mktemp -d)"

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

make_target_file() {
    local name="$1"
    local file="$TEST_ROOT/$name"
    cat > "$file" <<'EOF'
---
name: using-superpowers
description: fixture
---

## Skill Priority

- "Let's build X" → superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

### Full Routing Reference

<!-- BEGIN GENERATED ROUTING TABLE -->
<!-- END GENERATED ROUTING TABLE -->

## Red Flags
EOF
    printf '%s\n' "$file"
}

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

test_brainstorming_omits_use_when_prefix() {
    local desc="brainstorming keeps its 'You MUST' wording and 'Use when' descriptions are unchanged"
    local target
    target="$(make_target_file "prefix.md")"

    "$GENERATOR" "$target" > /dev/null

    if grep -q '^- You MUST use this before any creative work → superpowers:brainstorming$' "$target" \
        && grep -q '^- Use when encountering any bug, test failure, or unexpected behavior, before proposing fixes → superpowers:systematic-debugging$' "$target"; then
        pass "$desc"
    else
        fail "$desc"
        grep -E 'brainstorming|systematic-debugging' "$target" | sed 's/^/      /'
    fi
}

test_separator_styles_both_truncate() {
    local desc="both ' - ' and ' — ' separator styles truncate the clause correctly"
    local target
    target="$(make_target_file "separators.md")"

    "$GENERATOR" "$target" > /dev/null

    if grep -q '^- Use when implementation is complete, all tests pass, and you need to decide how to integrate the work → superpowers:finishing-a-development-branch$' "$target" \
        && grep -q '^- Use when a problem was just solved, a durable project convention was established, or project-specific vocabulary emerged → superpowers:compound-learnings$' "$target"; then
        pass "$desc"
    else
        fail "$desc"
        grep -E 'finishing-a-development-branch|compound-learnings' "$target" | sed 's/^/      /'
    fi
}

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

test_check_mode_exits_0_when_in_sync() {
    local desc="--check exits 0 when routing table already matches"
    local target
    target="$(make_target_file "check-sync.md")"

    "$GENERATOR" "$target" > /dev/null

    if "$GENERATOR" --check "$target" > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc (expected exit 0)"
    fi
}

test_check_mode_exits_1_when_stale() {
    local desc="--check exits 1 with a diff when routing table is stale"
    local target
    target="$(make_target_file "check-stale.md")"
    # Marked block left empty (never generated) — guaranteed stale.

    local output
    if output="$("$GENERATOR" --check "$target" 2>&1)"; then
        fail "$desc (expected non-zero exit)"
    else
        if printf '%s' "$output" | grep -q '^+- You MUST use this before any creative work'; then
            pass "$desc"
        else
            fail "$desc (diff did not mention brainstorming addition)"
            printf '%s\n' "$output" | sed 's/^/      /'
        fi
    fi
}

test_check_mode_does_not_write() {
    local desc="--check never modifies the target file"
    local target
    target="$(make_target_file "check-readonly.md")"
    local before after
    before="$(cat "$target")"

    "$GENERATOR" --check "$target" > /dev/null 2>&1 || true
    after="$(cat "$target")"

    if [ "$before" = "$after" ]; then
        pass "$desc"
    else
        fail "$desc (file was modified)"
    fi
}

test_default_mode_preserves_content_outside_markers() {
    local desc="default mode only touches content between the markers"
    local target
    target="$(make_target_file "preserve.md")"

    "$GENERATOR" "$target" > /dev/null

    if grep -q '^## Skill Priority$' "$target" \
        && grep -q '"Let'"'"'s build X" → superpowers:brainstorming first, then implementation skills.' "$target" \
        && grep -q '^## Red Flags$' "$target"; then
        pass "$desc"
    else
        fail "$desc"
        cat "$target" | sed 's/^/      /'
    fi
}

test_missing_markers_errors_clearly() {
    local desc="errors clearly when markers are missing from target file"
    local target="$TEST_ROOT/no-markers.md"
    printf '# No markers here\n' > "$target"

    local output
    if output="$("$GENERATOR" "$target" 2>&1)"; then
        fail "$desc (expected non-zero exit)"
    else
        if printf '%s' "$output" | grep -q 'marker'; then
            pass "$desc"
        else
            fail "$desc (error message did not mention 'marker')"
            printf '%s\n' "$output" | sed 's/^/      /'
        fi
    fi
}

test_check_mode_passes_against_real_using_superpowers() {
    local desc="--check exits 0 against the real skills/using-superpowers/SKILL.md"

    if "$GENERATOR" --check > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc (expected exit 0 — real using-superpowers/SKILL.md routing table is stale)"
    fi
}

echo "Running generate-routing-table.sh tests..."
test_extraction_produces_one_entry_per_routable_skill_alphabetical
test_skips_skills_that_disable_model_invocation
test_description_without_use_when_is_verbatim
test_brainstorming_omits_use_when_prefix
test_separator_styles_both_truncate
test_check_mode_exits_0_when_in_sync
test_check_mode_exits_1_when_stale
test_check_mode_does_not_write
test_default_mode_preserves_content_outside_markers
test_missing_markers_errors_clearly
test_check_mode_passes_against_real_using_superpowers

if [ "$FAILURES" -eq 0 ]; then
    echo "All tests passed."
    exit 0
else
    echo "$FAILURES test(s) failed."
    exit 1
fi
