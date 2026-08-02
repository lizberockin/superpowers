#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
GENERATOR="$REPO_ROOT/scripts/generate-skill-catalog.sh"

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
# Fixture README

## What's Inside

### Skills Library

<!-- BEGIN GENERATED SKILL CATALOG -->
<!-- END GENERATED SKILL CATALOG -->

## Philosophy
EOF
    printf '%s\n' "$file"
}

test_extraction_produces_18_skills_alphabetical() {
    local desc="extraction produces 18 skills, alphabetically sorted"
    local target
    target="$(make_target_file "extraction.md")"

    "$GENERATOR" "$target" > /dev/null

    local block
    block="$(sed -n '/<!-- BEGIN GENERATED SKILL CATALOG -->/,/<!-- END GENERATED SKILL CATALOG -->/p' "$target" | sed '1d;$d')"

    local count
    count="$(printf '%s\n' "$block" | grep -c '^- \*\*')"
    if [ "$count" -eq 18 ]; then
        pass "$desc (18 bullets)"
    else
        fail "$desc (expected 18 bullets, got $count)"
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

test_brainstorming_quotes_stripped() {
    local desc="brainstorming's quoted YAML description has quotes stripped"
    local target
    target="$(make_target_file "quotes.md")"

    "$GENERATOR" "$target" > /dev/null

    if grep -q '\*\*brainstorming\*\* — You MUST use this before any creative work' "$target" \
        && ! grep -q '\*\*brainstorming\*\* — "You MUST' "$target"; then
        pass "$desc"
    else
        fail "$desc"
        grep 'brainstorming' "$target" | sed 's/^/      /'
    fi
}

test_check_mode_exits_0_when_in_sync() {
    local desc="--check exits 0 when catalog already matches"
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
    local desc="--check exits 1 with a diff when catalog is stale"
    local target
    target="$(make_target_file "check-stale.md")"
    # Marked block left empty (never generated) — guaranteed stale.

    local output
    if output="$("$GENERATOR" --check "$target" 2>&1)"; then
        fail "$desc (expected non-zero exit)"
    else
        if printf '%s' "$output" | grep -q '^+- \*\*brainstorming\*\*'; then
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

    if grep -q '^# Fixture README$' "$target" \
        && grep -q '^## Philosophy$' "$target" \
        && grep -q '^### Skills Library$' "$target"; then
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

test_check_mode_passes_against_real_readme() {
    local desc="--check exits 0 against the real README.md"

    if "$GENERATOR" --check > /dev/null 2>&1; then
        pass "$desc"
    else
        fail "$desc (expected exit 0 — real README.md catalog is stale)"
    fi
}

echo "Running generate-skill-catalog.sh tests..."
test_extraction_produces_18_skills_alphabetical
test_brainstorming_quotes_stripped
test_check_mode_exits_0_when_in_sync
test_check_mode_exits_1_when_stale
test_check_mode_does_not_write
test_default_mode_preserves_content_outside_markers
test_missing_markers_errors_clearly
test_check_mode_passes_against_real_readme

if [ "$FAILURES" -eq 0 ]; then
    echo "All tests passed."
    exit 0
else
    echo "$FAILURES test(s) failed."
    exit 1
fi
