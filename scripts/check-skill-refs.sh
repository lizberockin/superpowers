#!/usr/bin/env bash
#
# Check every skill cross-reference in skills/*/SKILL.md against the real
# skills/ directory tree, and report any that don't resolve.
#
# Usage:
#   scripts/check-skill-refs.sh [file ...]
#
# Two reference shapes are checked:
#   1. Any `superpowers:<name>` token, anywhere in the file — this is the
#      unambiguous namespaced form used in routing tables and invocations.
#   2. Any backtick-quoted name on a "**See also:**" line that is
#      introduced as its own catalog-style entry (`` `name` — ... ``) —
#      the shape a dangling forward-reference to a never-built skill takes.
#      Bare mentions elsewhere in a line (e.g. "use `ideate` first") are not
#      checked here; they restate a name a superpowers: token already
#      established elsewhere on the same line.
#
# Exits 0 if every reference resolves to a real skills/<name>/ directory,
# or 1 (printing each orphan) if any don't. No CI wiring — run by hand
# before committing a skill edit.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

die() {
  echo "error: $*" >&2
  exit 1
}

# Emits one "file<TAB>line<TAB>ref-name" row per reference found in a file,
# for both shapes described above. Em dashes are normalized to hyphens
# before matching so a single ASCII-only regex covers both separators.
extract_refs() {
  local file="$1"
  awk -v file="$file" '
    {
      line = $0
      gsub(/—/, "-", line)

      rest = line
      while (match(rest, /superpowers:[a-z][a-z0-9-]*/)) {
        ref = substr(rest, RSTART, RLENGTH)
        sub(/^superpowers:/, "", ref)
        print file "\t" FNR "\t" ref
        rest = substr(rest, RSTART + RLENGTH)
      }

      if (line ~ /\*\*See also:\*\*/) {
        rest = line
        while (match(rest, /`(superpowers:)?[A-Za-z0-9_-]+` - /)) {
          ref = substr(rest, RSTART, RLENGTH)
          gsub(/`/, "", ref)
          sub(/^superpowers:/, "", ref)
          sub(/ - $/, "", ref)
          print file "\t" FNR "\t" ref
          rest = substr(rest, RSTART + RLENGTH)
        }
      }
    }
  ' "$file"
}

main() {
  local files=("$@")
  if [ "${#files[@]}" -eq 0 ]; then
    for f in "$REPO_ROOT"/skills/*/SKILL.md; do
      files+=("$f")
    done
  fi

  local file line_num ref orphans=0 checked=0
  for file in "${files[@]}"; do
    [ -f "$file" ] || die "file not found: $file"
    while IFS=$'\t' read -r _ line_num ref; do
      [ -n "$ref" ] || continue
      checked=$((checked + 1))
      if [ ! -d "$REPO_ROOT/skills/$ref" ]; then
        orphans=$((orphans + 1))
        echo "$file:$line_num: dangling reference to '$ref' — no skills/$ref/ directory" >&2
      fi
    done < <(extract_refs "$file")
  done

  if [ "$orphans" -eq 0 ]; then
    echo "All $checked skill references resolve."
    exit 0
  else
    echo "error: $orphans of $checked skill references are dangling" >&2
    exit 1
  fi
}

main "$@"
