# Routing Table Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Expand `using-superpowers/SKILL.md`'s "Skill Priority" section from 2 hand-written routing examples to full coverage of all 15 other skills, generated from each skill's own `description` frontmatter.

**Architecture:** A standalone bash script (`scripts/generate-routing-table.sh`), same shape as the existing `scripts/generate-skill-catalog.sh` (`[--check] [target-file]`, marker-delimited region, default target the real file). It extracts a trigger clause from each skill's description (strip leading `Use when `, truncate at the first ` — ` or ` - ` separator) and writes one bullet per skill, excluding `using-superpowers` itself. Built and tested first against fixture files (Task 1), then applied to the real `skills/using-superpowers/SKILL.md` (Task 2).

**Tech Stack:** Bash, matching `generate-skill-catalog.sh` and `lint-shell.sh`. No shared lib — this project intentionally keeps the ~15 lines of frontmatter-extraction logic duplicated rather than refactoring both scripts into a shared module (spec: "Non-goals").

## Global Constraints

- No CI wiring. `--check` is the full scope of drift prevention. (Spec: "Non-goals")
- `using-superpowers` is excluded from its own generated list — 15 entries, not 16. (Spec: "Non-goals")
- The two existing hand-written examples ("Let's build X" / "Fix this bug") stay in place unchanged; the generated block is additive, under a new "### Full Routing Reference" heading. (Spec: "Design, section 3")
- Script writes are scoped to content between `<!-- BEGIN GENERATED ROUTING TABLE -->` and `<!-- END GENERATED ROUTING TABLE -->` — nothing outside those markers may be touched.
- Skills sorted alphabetically by the `name` field, same as the catalog script.
- `brainstorming`'s line omits the `Use when` prefix (its description doesn't have one); every other line includes it. (Spec: "Design, section 2")

---

### Task 1: Write and test the generator script

**Files:**
- Create: `scripts/generate-routing-table.sh`
- Test: `tests/skill-catalog/test-generate-routing-table.sh`

**Interfaces:**
- Consumes: `skills/*/SKILL.md` frontmatter (`name:` and `description:` fields) — read-only, real repo data.
- Produces: `scripts/generate-routing-table.sh [--check] [target-file]`. Default `target-file` is `skills/using-superpowers/SKILL.md`. Exit 0 on success; exit 1 with an error/diff on stderr for staleness or missing markers.

- [ ] **Step 1: Write the failing test**

Create `tests/skill-catalog/test-generate-routing-table.sh`:

```bash
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

test_extraction_produces_15_entries_alphabetical() {
    local desc="extraction produces 15 entries (excludes using-superpowers), alphabetically sorted"
    local target
    target="$(make_target_file "extraction.md")"

    "$GENERATOR" "$target" > /dev/null

    local block
    block="$(sed -n '/<!-- BEGIN GENERATED ROUTING TABLE -->/,/<!-- END GENERATED ROUTING TABLE -->/p' "$target" | sed '1d;$d')"

    local count
    count="$(printf '%s\n' "$block" | grep -c 'superpowers:')"
    if [ "$count" -eq 15 ]; then
        pass "$desc (15 entries)"
    else
        fail "$desc (expected 15 entries, got $count)"
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
test_extraction_produces_15_entries_alphabetical
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
```

Make it executable: `chmod +x tests/skill-catalog/test-generate-routing-table.sh`

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/skill-catalog/test-generate-routing-table.sh`
Expected: FAIL immediately — the script aborts, `.../scripts/generate-routing-table.sh: No such file or directory`, because the script does not exist yet.

- [ ] **Step 3: Write the generator script**

Create `scripts/generate-routing-table.sh`:

```bash
#!/usr/bin/env bash
#
# Generate the "Full Routing Reference" block in using-superpowers/SKILL.md
# from every other skill's frontmatter description.
#
# Usage:
#   scripts/generate-routing-table.sh [--check] [target-file]
#
# Default mode regenerates the content between the
# "<!-- BEGIN GENERATED ROUTING TABLE -->" / "<!-- END ... -->" markers in
# target-file (default: skills/using-superpowers/SKILL.md) from every other
# skills/*/SKILL.md frontmatter, and writes the result back to target-file.
#
# --check computes the same generated content but does not write; it exits
# 0 if target-file's marked block already matches, or exits 1 and prints a
# diff to stderr if it's stale.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BEGIN_MARKER="<!-- BEGIN GENERATED ROUTING TABLE -->"
END_MARKER="<!-- END GENERATED ROUTING TABLE -->"
SELF_SKILL="using-superpowers"

die() {
  echo "error: $*" >&2
  exit 1
}

extract_frontmatter_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    NR==1 && $0=="---" { in_fm=1; next }
    in_fm && $0=="---" { exit }
    in_fm && index($0, field ":") == 1 {
      sub("^" field ": *", "")
      print
      exit
    }
  ' "$file"
}

strip_quotes() {
  local s="$1"
  s="${s#\"}"
  s="${s%\"}"
  printf '%s' "$s"
}

# Strips a leading "Use when " prefix, then truncates at the first
# " — " (em dash) or " - " (hyphen) separator, whichever comes first.
# Descriptions use these inconsistently to separate the trigger clause
# from the mechanism/rationale clause that follows.
extract_trigger_clause() {
  local desc="$1"
  case "$desc" in
    "Use when "*) desc="${desc#Use when }" ;;
  esac
  printf '%s' "$desc" | sed -E 's/ (—|-) .*$//'
}

generate_routing_block() {
  local skill_file name desc clause
  for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    name="$(extract_frontmatter_field "$skill_file" "name")"
    [ -n "$name" ] || die "no 'name' field found in $skill_file"
    [ "$name" = "$SELF_SKILL" ] && continue
    desc="$(extract_frontmatter_field "$skill_file" "description")"
    desc="$(strip_quotes "$desc")"
    clause="$(extract_trigger_clause "$desc")"
    printf '%s\t%s\n' "$name" "$clause"
  done | sort -k1,1 | while IFS=$'\t' read -r name clause; do
    case "$clause" in
      "Use when "*|"You MUST"*) printf -- '- %s → superpowers:%s\n' "$clause" "$name" ;;
      *) printf -- '- Use when %s → superpowers:%s\n' "$clause" "$name" ;;
    esac
  done
}

extract_marked_block() {
  local file="$1"
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" '
    $0==begin { flag=1; next }
    $0==end { flag=0 }
    flag { print }
  ' "$file"
}

replace_marked_block() {
  local file="$1" new_content_file="$2"
  awk -v begin="$BEGIN_MARKER" -v end="$END_MARKER" -v new_content_file="$new_content_file" '
    $0==begin {
      print
      while ((getline line < new_content_file) > 0) print line
      skipping=1
      next
    }
    $0==end { skipping=0; print; next }
    skipping { next }
    { print }
  ' "$file"
}

main() {
  local check_mode=0
  local target_file=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --check) check_mode=1; shift ;;
      *) target_file="$1"; shift ;;
    esac
  done

  [ -n "$target_file" ] || target_file="$REPO_ROOT/skills/using-superpowers/SKILL.md"
  [ -f "$target_file" ] || die "target file not found: $target_file"

  grep -qF "$BEGIN_MARKER" "$target_file" || die "marker '$BEGIN_MARKER' not found in $target_file"
  grep -qF "$END_MARKER" "$target_file" || die "marker '$END_MARKER' not found in $target_file"

  local generated_file existing_file output_file
  generated_file="$(mktemp)"
  existing_file="$(mktemp)"
  output_file="$(mktemp)"
  trap 'rm -f "$generated_file" "$existing_file" "$output_file"' EXIT

  generate_routing_block > "$generated_file"

  if [ "$check_mode" -eq 1 ]; then
    extract_marked_block "$target_file" > "$existing_file"
    local diff_output
    if diff_output="$(diff -u "$existing_file" "$generated_file")"; then
      echo "Routing table is in sync."
      exit 0
    else
      echo "error: routing table is stale" >&2
      echo "$diff_output" >&2
      exit 1
    fi
  else
    replace_marked_block "$target_file" "$generated_file" > "$output_file"
    mv "$output_file" "$target_file"
    echo "Regenerated routing table in $target_file"
  fi
}

main "$@"
```

Make it executable: `chmod +x scripts/generate-routing-table.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `tests/skill-catalog/test-generate-routing-table.sh`
Expected: all checks pass except the final real-file test (`test_check_mode_passes_against_real_using_superpowers`), which fails until Task 2 adds the markers to the real file — confirm that is the *only* failure at this point.

- [ ] **Step 5: Commit**

```bash
git add scripts/generate-routing-table.sh tests/skill-catalog/test-generate-routing-table.sh
git commit -m "Add routing table generator script with drift-check mode"
```

---

### Task 2: Apply the generator to using-superpowers/SKILL.md

**Files:**
- Modify: `skills/using-superpowers/SKILL.md` (Skill Priority section)

**Interfaces:**
- Consumes: `scripts/generate-routing-table.sh` (Task 1's CLI, default target `skills/using-superpowers/SKILL.md`)
- Produces: a `SKILL.md` whose "Full Routing Reference" subsection is fully generated and verifiably in sync via `--check`

- [ ] **Step 1: Insert the new subsection and markers**

Using the Edit tool, in `skills/using-superpowers/SKILL.md`, change:

```markdown
- "Let's build X" → superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

## Red Flags
```

to:

```markdown
- "Let's build X" → superpowers:brainstorming first, then implementation skills.
- "Fix this bug" → superpowers:systematic-debugging first, then domain skills.

### Full Routing Reference

<!-- BEGIN GENERATED ROUTING TABLE -->
<!-- END GENERATED ROUTING TABLE -->

## Red Flags
```

- [ ] **Step 2: Run the generator against the real file**

Run: `scripts/generate-routing-table.sh`
Expected output: `Regenerated routing table in /absolute/path/to/skills/using-superpowers/SKILL.md`

- [ ] **Step 3: Verify with --check**

Run: `scripts/generate-routing-table.sh --check`
Expected: `Routing table is in sync.` and exit code 0.

- [ ] **Step 4: Read-through verification**

Read `skills/using-superpowers/SKILL.md`'s new "Full Routing Reference" section and confirm:
- All 15 other skills are present (not `using-superpowers` itself)
- Entries are alphabetically sorted by name
- `brainstorming`'s line reads naturally without a doubled "Use when"
- The rest of the file (mandate block, "The Rule", the two hand-written examples, "Red Flags", "User Instructions") is unchanged

Run: `grep -c 'superpowers:' skills/using-superpowers/SKILL.md`
Expected: `17` (15 generated + the 2 existing hand-written examples)

- [ ] **Step 5: Run the full test suite once more**

Run: `tests/skill-catalog/test-generate-routing-table.sh`
Expected: `All tests passed.` (9/9, including the real-file check that could not pass until this task landed)

Also re-run the sibling suite to confirm no cross-contamination:

Run: `tests/skill-catalog/test-generate-skill-catalog.sh`
Expected: `All tests passed.` (unchanged, 9/9)

- [ ] **Step 6: Commit**

```bash
git add skills/using-superpowers/SKILL.md
git commit -m "Regenerate routing table: expand Skill Priority to full 15-skill coverage"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1 implements spec sections 1-2 (trigger-clause extraction, generator script) in full, plus every check listed in the spec's "Testing / Verification" section. Task 2 implements spec section 3 (SKILL.md restructure) and confirms the fix (15/15 other skills now routable).
- **No placeholders:** Both tasks contain complete, literal file contents.
- **Ordering:** Task 1 must precede Task 2 — the script doesn't exist until Task 1 completes, and the real-file regression test in Task 1's own suite can't pass until Task 2 adds the markers. This mirrors the same sequencing already used for the skill-catalog-generator plan.
- **Type/interface consistency:** The CLI signature (`[--check] [target-file]`) is identical to `generate-skill-catalog.sh`'s, and Task 2 invokes it exactly as documented (no arguments = default `skills/using-superpowers/SKILL.md` target).
