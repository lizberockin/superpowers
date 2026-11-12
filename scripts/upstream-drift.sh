#!/usr/bin/env bash
#
# Classify every skill, and every other top-level path, against upstream so
# syncing the fork becomes a short list of per-unit decisions.
#
# Usage:
#   scripts/upstream-drift.sh [upstream-ref]
#
# upstream-ref defaults to upstream/main. For each unit the script compares the
# git tree (or blob) hash at the merge-base, at upstream and at HEAD, and
# prints one label per unit:
#   untouched      same at all three (counted, not listed)
#   in-sync        upstream and HEAD match, merge-base differs
#   fork-only      only HEAD changed
#   upstream-only  only upstream changed; the adoption command is printed
#   both-changed   all three differ; diff-stat commands are printed
#
# Committed state only. Read-only: never writes to the working tree, the index
# or git config, and makes no network calls. Run `git fetch upstream` first
# for fresh results.
set -euo pipefail

usage() {
  awk 'NR == 1 { next } /^#/ { sub(/^# ?/, ""); print; next } { exit }' "$0"
}

die() {
  echo "error: $*" >&2
  exit 1
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

UPSTREAM="${1:-upstream/main}"

git rev-parse --git-dir > /dev/null 2>&1 || die "not inside a git repository"
git rev-parse --verify --quiet "${UPSTREAM}^{commit}" > /dev/null ||
  die "upstream ref '$UPSTREAM' not found (try: git fetch upstream)"
# ls-tree paths are relative to the working directory; the unit names must be repo-root-relative.
cd "$(git rev-parse --show-toplevel)"
BASE="$(git merge-base HEAD "$UPSTREAM")" ||
  die "no merge-base between HEAD and $UPSTREAM"

hash_at() {
  git rev-parse --verify --quiet "$1:$2" 2>/dev/null || echo absent
}

skills_at() {
  git -c core.quotePath=false ls-tree --name-only "$1" skills/ 2>/dev/null || true
}

others_at() {
  git -c core.quotePath=false ls-tree --name-only "$1" | grep -vx 'skills' || true
}

union_of() {
  { "$1" "$BASE"; "$1" "$UPSTREAM"; "$1" HEAD; } | sort -u
}

classify() {
  local b="$1" u="$2" h="$3"
  if [ "$u" = "$h" ]; then
    if [ "$b" = "$u" ]; then echo untouched; else echo in-sync; fi
  elif [ "$b" = "$u" ]; then
    echo fork-only
  elif [ "$b" = "$h" ]; then
    echo upstream-only
  else
    echo both-changed
  fi
}

# Prints "label<TAB>path<TAB>upstream-hash" for each path in the newline list $1.
classify_all() {
  local path b u h
  while IFS= read -r path; do
    [ -n "$path" ] || continue
    b="$(hash_at "$BASE" "$path")"
    u="$(hash_at "$UPSTREAM" "$path")"
    h="$(hash_at HEAD "$path")"
    printf '%s\t%s\t%s\n' "$(classify "$b" "$u" "$h")" "$path" "$u"
  done <<< "$1"
}

print_section() {
  local label
  echo
  echo "== $1 =="
  for label in upstream-only both-changed fork-only in-sync; do
    printf '%s\n' "$2" | awk -F'\t' -v l="$label" '$1 == l { printf "%-14s %s\n", l, $2 }'
  done
}

print_adopt() {
  echo
  echo "== adopt upstream-only skills =="
  printf '%s\n' "$@" | awk -F'\t' -v ref="$UPSTREAM" '
    $1 == "upstream-only" && $3 == "absent" { printf "git rm -r -q %s\n", $2 }
    $1 == "upstream-only" && $3 != "absent" { printf "git rm -r -q --ignore-unmatch %s && git checkout %s -- %s\n", $2, ref, $2 }'
}

print_compare() {
  echo
  echo "== compare both-changed =="
  printf '%s\n' "$@" | awk -F'\t' -v base="$BASE" -v ref="$UPSTREAM" '
    $1 == "both-changed" { printf "git diff --stat %s %s -- %s ; git diff --stat %s HEAD -- %s\n", base, ref, $2, base, $2 }'
}

version_at() {
  git show "$1:.claude-plugin/plugin.json" 2>/dev/null |
    sed -n 's/.*"version": *"\([^"]*\)".*/\1/p' | head -n 1 || true
}

print_header() {
  local ahead behind up_v head_v
  ahead="$(git rev-list --count "$UPSTREAM..HEAD")"
  behind="$(git rev-list --count "HEAD..$UPSTREAM")"
  up_v="$(version_at "$UPSTREAM")"
  head_v="$(version_at HEAD)"
  echo "merge-base: $(git rev-parse --short "$BASE") | HEAD is $ahead ahead, $behind behind $UPSTREAM"
  echo "plugin version: upstream ${up_v:-unknown} | HEAD ${head_v:-unknown}"
}

count_line() {
  local label
  printf '%s:' "$1"
  for label in untouched in-sync fork-only upstream-only both-changed; do
    printf ' %s=%s' "$label" "$(printf '%s\n' "$2" | awk -F'\t' -v l="$label" '$1 == l { n++ } END { print n + 0 }')"
  done
  echo
}

print_summary() {
  echo
  echo "== summary =="
  count_line skills "$skill_rows"
  count_line "other paths" "$other_rows"
}

print_tip() {
  if [ -z "$(git config --get rerere.enabled || true)" ]; then
    echo
    echo "tip: git config rerere.enabled true"
  fi
}

skill_rows="$(classify_all "$(union_of skills_at)")"
other_rows="$(classify_all "$(union_of others_at)")"

print_header
print_section skills "$skill_rows"
print_section "other paths" "$other_rows"
print_summary
print_adopt "$skill_rows"
print_compare "$skill_rows" "$other_rows"
print_tip
