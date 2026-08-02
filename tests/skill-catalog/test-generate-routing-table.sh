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

test_extraction_produces_17_entries_alphabetical() {
    local desc="extraction produces 17 entries (excludes using-superpowers), alphabetically sorted"
    local target
    target="$(make_target_file "extraction.md")"

    "$GENERATOR" "$target" > /dev/null

    local block
    block="$(sed -n '/<!-- BEGIN GENERATED ROUTING TABLE -->/,/<!-- END GENERATED ROUTING TABLE -->/p' "$target" | sed '1d;$d')"

    local count
    count="$(printf '%s\n' "$block" | grep -c 'superpowers:')"
    if [ "$count" -eq 17 ]; then
        pass "$desc (17 entries)"
    else
        fail "$desc (expected 17 entries, got $count)"
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
    local desc="brainstorming's line omits the 'Use when' prefix; others include it"
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
test_extraction_produces_17_entries_alphabetical
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
