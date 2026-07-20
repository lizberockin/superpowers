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
    exit 0
  fi
}

main "$@"
