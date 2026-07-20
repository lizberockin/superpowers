# Skill Catalog Generator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace README.md's hand-maintained, currently-stale (14 of 16 skills) skill catalog with one generated from each skill's frontmatter, via a bash script with a `--check` mode for drift detection.

**Architecture:** A standalone bash script (`scripts/generate-skill-catalog.sh`) reads `skills/*/SKILL.md` frontmatter and writes a flat, alphabetical markdown list into a marker-delimited region of a target file (default `README.md`). Built and tested first against fixture files in isolation (Task 1), then applied to the real `README.md` (Task 2).

**Tech Stack:** Bash (matches the repo's existing `scripts/lint-shell.sh` convention — no new language dependency).

## Global Constraints

- No CI workflow. The `--check` mode is the full scope of drift prevention for this project. (Spec: "Non-goals")
- No new frontmatter fields. Catalog blurb text is each skill's existing `description` field, verbatim. (Spec: "Non-goals")
- No category grouping. Generated catalog is a flat, alphabetical list. (Spec: "Non-goals")
- The script's writes are scoped to content between `<!-- BEGIN GENERATED SKILL CATALOG -->` and `<!-- END GENERATED SKILL CATALOG -->` — nothing outside those markers may be touched. (Spec: "Design, section 1")
- Skills sorted alphabetically by the `name` field extracted from frontmatter. (Spec: "Design, section 1")

---

### Task 1: Write and test the generator script

**Files:**
- Create: `scripts/generate-skill-catalog.sh`
- Test: `tests/skill-catalog/test-generate-skill-catalog.sh`

**Interfaces:**
- Consumes: `skills/*/SKILL.md` frontmatter (`name:` and `description:` fields) — read-only, real repo data.
- Produces: `scripts/generate-skill-catalog.sh [--check] [target-file]` — a CLI other tooling (Task 2, and later idea 5) can invoke. Default `target-file` is `README.md` at repo root. Exit 0 on success (sync confirmed, or write completed); exit 1 with an error/diff on stderr for staleness or missing markers.

- [ ] **Step 1: Write the failing test**

Create `tests/skill-catalog/test-generate-skill-catalog.sh`:

```bash
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

test_extraction_produces_16_skills_alphabetical() {
    local desc="extraction produces 16 skills, alphabetically sorted"
    local target
    target="$(make_target_file "extraction.md")"

    "$GENERATOR" "$target" > /dev/null

    local block
    block="$(sed -n '/<!-- BEGIN GENERATED SKILL CATALOG -->/,/<!-- END GENERATED SKILL CATALOG -->/p' "$target" | sed '1d;$d')"

    local count
    count="$(printf '%s\n' "$block" | grep -c '^- \*\*')"
    if [ "$count" -eq 16 ]; then
        pass "$desc (16 bullets)"
    else
        fail "$desc (expected 16 bullets, got $count)"
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

echo "Running generate-skill-catalog.sh tests..."
test_extraction_produces_16_skills_alphabetical
test_brainstorming_quotes_stripped
test_check_mode_exits_0_when_in_sync
test_check_mode_exits_1_when_stale
test_check_mode_does_not_write
test_default_mode_preserves_content_outside_markers
test_missing_markers_errors_clearly

if [ "$FAILURES" -eq 0 ]; then
    echo "All tests passed."
    exit 0
else
    echo "$FAILURES test(s) failed."
    exit 1
fi
```

Make it executable: `chmod +x tests/skill-catalog/test-generate-skill-catalog.sh`

- [ ] **Step 2: Run the test to verify it fails**

Run: `tests/skill-catalog/test-generate-skill-catalog.sh`
Expected: FAIL immediately — the script aborts with an error like `.../scripts/generate-skill-catalog.sh: No such file or directory`, because `scripts/generate-skill-catalog.sh` does not exist yet.

- [ ] **Step 3: Write the generator script**

Create `scripts/generate-skill-catalog.sh`:

```bash
#!/usr/bin/env bash
#
# Generate the skill catalog in README.md from each skill's frontmatter.
#
# Usage:
#   scripts/generate-skill-catalog.sh [--check] [target-file]
#
# Default mode regenerates the content between the
# "<!-- BEGIN GENERATED SKILL CATALOG -->" / "<!-- END ... -->" markers in
# target-file (default: README.md at repo root) from skills/*/SKILL.md
# frontmatter, and writes the result back to target-file.
#
# --check computes the same generated content but does not write; it exits
# 0 if target-file's marked block already matches, or exits 1 and prints a
# diff to stderr if it's stale.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BEGIN_MARKER="<!-- BEGIN GENERATED SKILL CATALOG -->"
END_MARKER="<!-- END GENERATED SKILL CATALOG -->"

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

generate_catalog_block() {
  local skill_file name desc
  for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    name="$(extract_frontmatter_field "$skill_file" "name")"
    desc="$(extract_frontmatter_field "$skill_file" "description")"
    desc="$(strip_quotes "$desc")"
    [ -n "$name" ] || die "no 'name' field found in $skill_file"
    printf '%s\t%s\n' "$name" "$desc"
  done | sort -k1,1 | while IFS=$'\t' read -r name desc; do
    printf -- '- **%s** — %s\n' "$name" "$desc"
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

  [ -n "$target_file" ] || target_file="$REPO_ROOT/README.md"
  [ -f "$target_file" ] || die "target file not found: $target_file"

  grep -qF "$BEGIN_MARKER" "$target_file" || die "marker '$BEGIN_MARKER' not found in $target_file"
  grep -qF "$END_MARKER" "$target_file" || die "marker '$END_MARKER' not found in $target_file"

  local generated_file existing_file output_file
  generated_file="$(mktemp)"
  existing_file="$(mktemp)"
  output_file="$(mktemp)"
  trap 'rm -f "$generated_file" "$existing_file" "$output_file"' EXIT

  generate_catalog_block > "$generated_file"

  if [ "$check_mode" -eq 1 ]; then
    extract_marked_block "$target_file" > "$existing_file"
    local diff_output
    if diff_output="$(diff -u "$existing_file" "$generated_file")"; then
      echo "Skill catalog is in sync."
      exit 0
    else
      echo "error: skill catalog is stale" >&2
      echo "$diff_output" >&2
      exit 1
    fi
  else
    replace_marked_block "$target_file" "$generated_file" > "$output_file"
    mv "$output_file" "$target_file"
    echo "Regenerated skill catalog in $target_file"
  fi
}

main "$@"
```

Make it executable: `chmod +x scripts/generate-skill-catalog.sh`

- [ ] **Step 4: Run the test to verify it passes**

Run: `tests/skill-catalog/test-generate-skill-catalog.sh`
Expected: `All tests passed.` (7/7 checks pass, exit 0)

- [ ] **Step 5: Commit**

```bash
git add scripts/generate-skill-catalog.sh tests/skill-catalog/test-generate-skill-catalog.sh
git commit -m "Add skill catalog generator script with drift-check mode"
```

---

### Task 2: Apply the generator to README.md

**Files:**
- Modify: `README.md` (Skills Library subsection)

**Interfaces:**
- Consumes: `scripts/generate-skill-catalog.sh` (Task 1's CLI, default target `README.md`)
- Produces: a `README.md` whose "Skills Library" section is fully generated and verifiably in sync via `--check`

- [ ] **Step 1: Locate and replace the current catalog section**

Read `README.md` and confirm the `### Skills Library` subsection currently reads:

```markdown
### Skills Library

**Testing**
- **test-driven-development** - RED-GREEN-REFACTOR cycle (includes testing anti-patterns reference)

**Debugging**
- **systematic-debugging** - 4-phase root cause process (includes root-cause-tracing, defense-in-depth, condition-based-waiting techniques)
- **verification-before-completion** - Ensure it's actually fixed

**Collaboration** 
- **brainstorming** - Socratic design refinement
- **writing-plans** - Detailed implementation plans
- **executing-plans** - Batch execution with checkpoints
- **dispatching-parallel-agents** - Concurrent subagent workflows
- **requesting-code-review** - Pre-review checklist
- **receiving-code-review** - Responding to feedback
- **using-git-worktrees** - Parallel development branches
- **finishing-a-development-branch** - Merge/PR decision workflow
- **subagent-driven-development** - Fast iteration with two-stage review (spec compliance, then code quality)

**Meta**
- **writing-skills** - Create new skills following best practices (includes testing methodology)
- **using-superpowers** - Introduction to the skills system
```

Using the Edit tool, replace that entire block with:

```markdown
### Skills Library

<!-- BEGIN GENERATED SKILL CATALOG -->
<!-- END GENERATED SKILL CATALOG -->
```

If the exact wording has drifted from what's shown above, use the literal text `### Skills Library` as the start anchor and the line immediately before `## Philosophy` as the end anchor instead.

- [ ] **Step 2: Run the generator against the real README**

Run: `scripts/generate-skill-catalog.sh`
Expected output: `Regenerated skill catalog in /absolute/path/to/README.md`

- [ ] **Step 3: Verify with --check**

Run: `scripts/generate-skill-catalog.sh --check`
Expected: `Skill catalog is in sync.` and exit code 0.

- [ ] **Step 4: Read-through verification**

Read `README.md`'s `### Skills Library` section and confirm:
- All 16 skills are present, including `compound-learnings` and `ideate` (previously missing)
- Entries are alphabetically sorted by name
- No `**Testing**` / `**Debugging**` / `**Collaboration**` / `**Meta**` category headers remain
- Every other section of `README.md` (How it works, Installation, See it in action, The Basic Workflow, Philosophy, License, telemetry note) is unchanged

Run: `grep -c '^- \*\*' README.md`
Expected: `16`

- [ ] **Step 5: Run the full test suite once more**

Run: `tests/skill-catalog/test-generate-skill-catalog.sh`
Expected: `All tests passed.` (confirms Task 2's edits to README.md didn't break the generator's fixture-based tests, which never touch the real README.md)

- [ ] **Step 6: Commit**

```bash
git add README.md
git commit -m "Regenerate skill catalog: fixes missing compound-learnings and ideate entries"
```

---

## Self-Review Notes

- **Spec coverage:** Task 1 implements spec section 1 (generator script, both modes) in full, plus the full test suite from the spec's "Testing / Verification" section (all five listed checks: 16-skill extraction, quote-stripping as part of extraction correctness, `--check` sync/stale/no-write behavior, and marker-scoped writes — plus one additional edge-case test for missing markers, since a silent no-op there would be a real bug). Task 2 implements spec section 2 (README restructure) and confirms the fix to the original bug (16 skills now present).
- **No placeholders:** Both tasks contain complete, literal file contents.
- **Ordering:** Task 1 must precede Task 2 — the script doesn't exist until Task 1 completes, and Task 2 depends on invoking it. This is the only cross-task dependency in this plan.
- **Type/interface consistency:** The CLI signature (`[--check] [target-file]`) is identical between Task 1's test file and Task 1's script implementation, and Task 2 invokes it exactly as documented (no arguments = default `README.md` target).
