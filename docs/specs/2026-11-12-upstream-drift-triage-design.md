# Upstream drift triage: per-skill classification of the fork against obra/superpowers

## Goal

Add a read-only script, `scripts/upstream-drift.sh`, that classifies every skill (and every other top-level path) as untouched, in sync, fork-only, upstream-only or changed on both sides, so that syncing the fork with upstream becomes a short worklist of per-skill decisions instead of a 59-commit rebase.

## Problem

The fork is 83 commits ahead of and 59 behind `upstream/main` (merge-base `d884ae0`). That number is the wrong unit: a skill library conflicts file by file, and most files changed on only one side. From the merge-base, six skills changed only upstream (`receiving-code-review`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `verification-before-completion`, and a new `diagnosing-superpowers`), nine changed on both sides (`brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `requesting-code-review`, `subagent-driven-development`, `using-superpowers`, `writing-plans`, `writing-skills`), and the rest are fork-only.

Today the fork tracks upstream by hand-cherry-picking by PR number (`#2125`, `#2063`, `#2024`). Nothing says which upstream changes remain, so the gap grows with every upstream release (7.0.2 at time of writing, against the fork's 6.3.0), including upstream work aimed at this fork's open pains ("skills that better survive compaction" in 7.0.1, "leaner plans from writing-plans" in 6.4.2).

Considered and rejected: a whole-branch merge or rebase (nine skills conflict at once and upstream rewrites get reviewed together with fork edits; `rerere` only helps repeated conflicts), and a per-commit triage as the primary view (roughly doubles the script for information the per-skill view already gives).

## Design

### Interface

`scripts/upstream-drift.sh [upstream-ref]`, default `upstream/main`. Follows the conventions of `scripts/check-skill-refs.sh`: a usage header comment, `set -euo pipefail`, a `die()` helper, self-contained with no shared library. Read-only: it never writes to the working tree, the index or git config, and makes no network calls. If the ref does not resolve it exits non-zero with a hint to run `git fetch upstream`; if there is no merge-base it exits non-zero with an error. Otherwise it exits 0, since it is a report, not a check.

### Units

- Every directory under `skills/`, taken as the union of names present at the merge-base, at the upstream ref and at `HEAD`, so new upstream skills and fork-only skills both appear.
- Every other top-level entry (`hooks/`, `scripts/`, `tests/`, `docs/`, `assets/`, `README.md`, `.claude-plugin/` and so on) as one unit each, reported in a second section.

### Classification

For each unit, take the tree or blob hash at the merge-base (b), upstream (u) and `HEAD` (h) with `git rev-parse <ref>:<path>`; a unit missing at a ref has the value "absent".

| Condition | Label | Action printed |
|---|---|---|
| b == u == h | `untouched` | none |
| u == h, b differs | `in-sync` | none (an adopted skill appears here automatically) |
| b == u, h differs | `fork-only` | none |
| b == h, u differs | `upstream-only` | for skills only: `git rm -r -q --ignore-unmatch <path> && git checkout <upstream-ref> -- <path>` (so files upstream deleted inside the directory go too), or `git rm -r -q <path>` when upstream deleted it; other paths are listed but get no command |
| all three differ | `both-changed` | a `git diff --stat` pointer between the merge-base and each side for hand merging |

### Output

- A header: merge-base short SHA, commits ahead and behind, and the plugin version in `.claude-plugin/plugin.json` at upstream versus `HEAD`.
- The skills section and the other-paths section, each grouped by label with `untouched` omitted unless requested by a future flag.
- A one-line count per label, then a copy-pasteable block of adoption commands for the `upstream-only` skills (`== adopt upstream-only skills ==`), then a `== compare both-changed ==` block with the two `git diff --stat` commands for each both-changed unit. Upstream-only other paths are listed but given no commands, because top-level paths include harness integrations the fork deliberately omits and pasting commands for them would re-add what was removed on purpose.
- A tip when `git config rerere.enabled` is unset. The script only prints it and never sets it.

### Decisions

- **No state file.** An adopted skill's hash equals upstream's, so it shows as `in-sync` with nothing to record. The one thing this cannot remember is a deliberate decision to decline an upstream change; those keep showing as `upstream-only`. Revisit only if that becomes annoying.
- **Hash comparison, not text diff.** Tree hashes are exact and cheap, and the merge-base acts as the lockfile, so there is nothing to maintain.
- **Bash.** The repo's scripts and tests are bash; matching that outweighs a general preference for Python.

### Known limits

- `upstream-only` means no textual conflict, not no semantic conflict: an adopted skill may cross-reference something the fork changed, such as the routing table in `skills/using-superpowers/SKILL.md`.
- Unit-level hashes say a unit changed, not how; the diff-stat pointer is the way in.
- The other-paths section is coarse. A path the fork deleted on purpose that upstream kept changing shows as `both-changed`, and new upstream top-level paths show as `upstream-only`; both are reviewed by hand, not adopted by script.
- The script does not decide whether the fork should keep tracking upstream; it supplies the evidence for that decision.

## Testing

`tests/upstream-drift/test-upstream-drift.sh`, in the style of `tests/skill-catalog/test-generate-routing-table.sh` (pass and fail helpers, a temp directory removed on exit), written before the script. It builds a throwaway repository with a base commit, an `upstream` branch and a fork branch, and asserts: each of the five labels; the adoption command for an upstream-only skill; `git rm -r` for a skill upstream deleted; a skill added only upstream (upstream-only) and one added only in the fork (fork-only); the other-paths section; ahead and behind counts; the rerere tip appearing and disappearing with the config; and the error for a missing upstream ref.

## First run

After the script passes its tests, run it on the real fork and report the result, including how `skills/diagnosing-bugs/SKILL.md` and `skills/systematic-debugging/SKILL.md` overlap. No skill is changed as part of this work.

## Non-goals

- No automatic adoption, rebasing or merging, and no writes of any kind.
- No per-commit triage and no PR-number extraction.
- No wiring into CI or a pre-commit hook; `scripts/check-all.sh` (a separate piece of work) can include it later.
- No decision about the fork's long-term relationship to upstream.
