# Unpin the plugin version and add one `check-all.sh` gate

## Goal

Make the fork's installed copy track its commits instead of a pinned version, and replace six unreferenced guard scripts and test suites with one command, `scripts/check-all.sh`, that actually runs them, with an opt-in pre-commit hook. Getting the gate to pass requires fixing the routing-table generator and regenerating the generated content that has drifted.

## Problem

**The install is pinned.** `.claude-plugin/plugin.json:4` and `.claude-plugin/marketplace.json` (the plugin entry) both say `6.3.0`. Per the plugin docs, a pinned version keeps installs on the cached copy even when new commits exist, and `claude plugin update` then reports "already at the latest version"; with `version` unset in both files the version comes from the commit SHA for git sources, and `plugin.json` wins over the marketplace entry when both are set. The installed copy at `~/.claude/plugins/cache/superpowers-dev/superpowers/6.3.0` is the 2026-08-04 snapshot (commit `afbbb0a`, 18 skills) while the marketplace checkout is at fork `main` with 8 newer commits, so none of the mattpocock-imported skills reached the install. Releases were a manual two-file edit that was never done. `claude plugin validate` passes (its only warning is a missing icon), so it cannot catch this.

**The guards are not run.** `scripts/check-skill-refs.sh` says "No CI wiring — run by hand", `tests/hooks`, `tests/shell-lint` and `tests/skill-catalog` are referenced by no runner, and there is no `.github/`. As a result the generated content has drifted on `main`: `scripts/generate-skill-catalog.sh --check` and `scripts/generate-routing-table.sh --check` both fail, and both generator test files fail because they hardcode counts that no longer hold (`tests/skill-catalog/test-generate-skill-catalog.sh` asserts 18 skills against 28 directories).

**The routing generator mishandles the imported skills.** `scripts/generate-routing-table.sh` (around lines 69-88) strips a leading "Use when " from each description and, when the remainder does not start with "Use when " or "You MUST", prepends "Use when ". Regenerating therefore produces lines such as "Use when A relentless interview to sharpen a plan or design.". It also lists skills marked `disable-model-invocation: true` (`grill-me`, `handoff`, `loop-me`, `teach`, `to-questionnaire`, `wait-what`), which the model should never route to. The table sits in `skills/using-superpowers/SKILL.md`, which `hooks/session-start` injects into every session.

`scripts/lint-shell.sh --all` also fails on `main` today, so the full tracked shell baseline cannot be part of the gate yet.

## Design

### Unpin the version

- Remove the `version` key from `.claude-plugin/plugin.json` and from the plugin entry in `.claude-plugin/marketplace.json`.
- Change `homepage` and `repository` in `plugin.json` to `https://github.com/lizberockin/superpowers`. Keep the `author` credit as is, since the work is upstream's.
- Chosen over a fork-owned version bumped by hand: the manual two-file step is the one that already failed once. The cost is that every merged push becomes an update, and that upstream merges will re-add the lines, which the guard below catches.
- After merge, `claude plugin update` should move the install off the August snapshot; this is documented behaviour and has not yet been observed.

### Fix the routing generator, then regenerate

- Skip any skill whose frontmatter has `disable-model-invocation: true`.
- When a description does not start with "Use when " or "You MUST", use it verbatim as the trigger clause, with no prefix.
- Leave the existing truncation rules and the documented latent edge cases alone.
- Regenerate the table in `skills/using-superpowers/SKILL.md` with the fixed generator. This adds the model-invocable imported and fork skills (`diagnosing-bugs`, `grilling`, `ideate`, `office-hours`, `wizard`, `writing-for-agents`) to the injected table; the user accepted that growth.
- Update `tests/skill-catalog/test-generate-routing-table.sh` first so it fails for the right reasons: cases for a skipped `disable-model-invocation` skill and a verbatim non-"Use when" description, and no hardcoded totals that depend on the real `skills/` directory.

### Regenerate the catalog

- Run `scripts/generate-skill-catalog.sh` to refresh the README block.
- Replace the hardcoded 18 in `tests/skill-catalog/test-generate-skill-catalog.sh` with a count computed from the fixture or from `skills/*/SKILL.md`, so it stops going stale.

### `scripts/check-all.sh`

Self-contained bash, same conventions as `scripts/check-skill-refs.sh` (usage header, `set -euo pipefail`, `die()`), run from the repo root regardless of the caller's directory. Runs each step, prints one `PASS`, `FAIL` or `SKIP` line per step, keeps going after a failure, prints a summary, and exits 1 if any step failed and 0 otherwise.

Steps, in order:

1. `scripts/generate-skill-catalog.sh --check`
2. `scripts/generate-routing-table.sh --check`
3. `scripts/check-skill-refs.sh`
4. `scripts/lint-shell.sh` in its default changed-files mode (not `--all`, which fails today on files this work does not touch); `SKIP` with a visible note when `shellcheck` is not installed
5. The deterministic test suites: `tests/hooks/test-*.sh`, `tests/shell-lint/test-*.sh`, `tests/skill-catalog/test-*.sh`, `tests/upstream-drift/test-*.sh` and `tests/claude-code/test-sdd-workspace.sh`, each run to completion; a directory that does not exist is ignored so the script works before the other branches that add tests merge
6. `claude plugin validate .`; `SKIP` with a note when `claude` is not installed
7. A guard that fails if either manifest contains a `version` key, so an upstream merge cannot silently re-pin the install

Not run: `tests/claude-code/*` other than the one named above, `tests/explicit-skill-requests/`, and `tests/brainstorm-server/`; those start Claude sessions or need installed packages. No CI wiring.

### Opt-in pre-commit hook

`.githooks/pre-commit` runs `scripts/check-all.sh` and fails the commit when it fails. `check-all.sh` unsets git's repository-location variables (`GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_PREFIX`, `GIT_COMMON_DIR`, `GIT_OBJECT_DIRECTORY`, `GIT_ALTERNATE_OBJECT_DIRECTORIES`, `GIT_NAMESPACE`) before running any step, because git exports them to hooks and several suites build and commit in throwaway repositories, which would otherwise write into the real repository's index. Enabled per clone with `git config core.hooksPath .githooks`; nothing enables it automatically. One line in `CONTRIBUTING.md` documents the script and the opt-in.

## Testing

- Routing generator: new cases in `tests/skill-catalog/test-generate-routing-table.sh`, written before the generator change (see above).
- Catalog test: the hardcoded count replaced; passes once the README block is regenerated.
- `tests/check-all/test-check-all.sh`, in the style of the existing tests (pass and fail helpers, temp directory removed on exit): builds a throwaway repository containing stub step scripts and asserts exit 0 when all steps pass, exit 1 with every later step still reported when one fails, a visible `SKIP` when a tool is absent, the guard failing on a manifest with `version` and passing without, and that the script works when invoked from a subdirectory.
- After the changes, `scripts/check-all.sh` itself must exit 0 on the branch.

## Non-goals

- No CI pipeline and no automatic enabling of the hook.
- No cleanup of the existing `scripts/lint-shell.sh --all` baseline failures, and no change to other generator behaviour.
- No icon, no other manifest changes beyond `version`, `homepage` and `repository`.
- No change to the upstream-drift script or the memory hooks; `check-all.sh` picks their tests up by glob once those branches merge.
