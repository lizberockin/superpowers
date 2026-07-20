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
    exit 0
  fi
}

main "$@"
