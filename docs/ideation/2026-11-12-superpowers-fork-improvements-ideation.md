---
date: 2026-11-12
topic: superpowers-fork-improvements
focus: what else to improve in the fork beyond the memory-hooks and delegation-contract work
mode: repo-grounded
---

# Ideation: Improving the superpowers fork

## Grounding Context

The fork (`lizberockin/superpowers`) is 83 commits ahead of and 59 behind `obra/superpowers`, with 28 skills (about 52.8k words), three hooks and a set of generator and check scripts.
Upstream is at 7.0.2; the fork's `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` both still say 6.3.0, and `plugin.json` still names the upstream author and repository.
The plugin installs from the fork's GitHub marketplace, so nothing reaches a session until it is pushed and the installed copy updates.

Work already in flight and not re-proposed here: the Completion Contract in `skills/dispatching-parallel-agents/SKILL.md`, the `wrap-up-nudge` and `pre-compact` hooks, the compaction nudge in `hooks/session-start`, the stale-entry check in `skills/compound-memory/SKILL.md`, and `tests/hooks/test-memory-hooks.sh`.

Facts the ideas rest on, each checked against the repo or the Claude Code docs:

- The installed plugin copy is the 2026-08-04 snapshot (commit `afbbb0a`, 18 skills). The marketplace checkout is at fork `main` (`565cca4`, 8 commits newer), so the ten skills imported from mattpocock/skills are not in the installed copy.
- Per the plugin docs, a pinned `version` keeps installs on the cached copy even when new commits exist, and `claude plugin update` reports "already at the latest version". With `version` unset, the version is the commit SHA.
- `docs/testing.md` (lines 6 and 23) and two test headers cite an `evals/` harness that does not exist.
- `scripts/generate-skill-catalog.sh --check` fails: the README catalog lists 18 of 28 skills, and `tests/skill-catalog/test-generate-skill-catalog.sh` hardcodes 18.
- `scripts/check-skill-refs.sh` says "No CI wiring — run by hand". No `.github/` exists, and `tests/hooks`, `tests/shell-lint` and `tests/skill-catalog` are referenced by no runner.
- `skills/compound-learnings/SKILL.md:714` holds an `<auto_invoke>` phrase block on a single line that no hook reads and that `hooks/wrap-up-nudge`'s parser cannot match. `docs/solutions/` and `CONCEPTS.md` do not exist.
- Always-loaded text is small: `hooks/session-start` injects 5,459 bytes (802 words) of `skills/using-superpowers/SKILL.md`, and all 28 description lines total 4,702 bytes.
- From the merge-base with upstream, six skills changed only upstream (`receiving-code-review`, `systematic-debugging`, `test-driven-development`, `using-git-worktrees`, `verification-before-completion`, plus a new `diagnosing-superpowers`) and nine changed on both sides (`brainstorming`, `dispatching-parallel-agents`, `executing-plans`, `finishing-a-development-branch`, `requesting-code-review`, `subagent-driven-development`, `using-superpowers`, `writing-plans`, `writing-skills`).

Decisions already made and honoured: no transcript scanning or always-on telemetry (the data is sensitive), `CONCEPTS.md` skipped, no new dependencies without asking, no new frontmatter fields without need, generated or linked content preferred over hand-copied.

## Topic Axes

1. Triggering and enforcement
2. Verification and testing of skills
3. Fork hygiene and upstream drift
4. Context and token cost
5. Memory and knowledge compounding

---

## Ranked Ideas

### 1. Fix the pinned plugin version so updates actually install

**Description:** Remove the `version` field from both `.claude-plugin/plugin.json` and `.claude-plugin/marketplace.json` so the installed version tracks the commit SHA, or bump both together on every release.
While there, replace the upstream author, homepage and repository fields in `plugin.json` with the fork's.
Run `claude plugin validate` afterwards, since it warns when the two manifests disagree.
**Axis:** Fork hygiene and upstream drift
**Basis:** `direct:` `.claude-plugin/plugin.json:4` and `.claude-plugin/marketplace.json:12` both say `6.3.0`, with 13 skill-touching commits since the last bump (`de3e430`).
The installed cache at `~/.claude/plugins/cache/superpowers-dev/superpowers/6.3.0` is at `afbbb0a` and holds 18 skills, while the marketplace checkout at `~/.claude/plugins/marketplaces/superpowers-dev` is at `565cca4`; `git log afbbb0a..main` shows 8 newer commits, including the mattpocock import, and the session's skill list has none of those skills.
`external:` the Claude Code plugin docs (`plugins/loading.md`) state that a pinned version keeps users on the cached copy and that `claude plugin update` then reports "already at the latest version", and that an unset version falls back to the commit SHA for git sources.
**Rationale:** Every other idea, and today's hooks work, ships through this path.
The evidence says it has already failed once: three months of fork changes never reached the installed copy.
**Downsides:** With no version, every push becomes an update, so a broken commit on `main` reaches the install.
Upstream merges will re-add the version lines, so this needs a note in the sync routine (idea 3).
Whether the cached copy refreshes on a plain `claude plugin update` after the change is documented but not yet observed here.
**Confidence:** 90%
**Complexity:** Low

### 2. Verify the compaction channel with a canary before building on it

**Description:** Add a manual-first check, `tests/hooks/verify-compact-channel.sh`, in which the `pre-compact` hook and the compact branch of `hooks/session-start` emit a unique token when an environment variable is set.
After a real compaction, ask the model what token it can see and compare.
If a headless run can drive `/compact`, grade it with a regex; if not, print a short manual checklist rather than automating.
Re-run after Claude Code upgrades.
**Axis:** Verification and testing of skills
**Basis:** `direct:` `docs/specs/2026-08-02-compound-memory-design.md` records "Unverified" for both whether `SessionStart` with `source=compact` reaches the post-compaction context and whether `PreCompact` stdout reaches the summarizer.
`tests/hooks/test-memory-hooks.sh` only asserts what the hooks print.
`external:` the hooks documentation confirms the `source` values and that `PreCompact` stdout is used as summary instructions, but is silent on delivery to the model.
**Rationale:** Two of the three hooks written today are dead weight if delivery fails, and nothing would show it.
A one-off pass or fail turns the one stated unknown into a decision to keep, redesign or remove them.
**Downsides:** Whether a headless `claude -p` session can trigger compaction is unproven, so the realistic first version is manual.
**Confidence:** 80%
**Complexity:** Medium

### 3. Triage upstream per skill instead of per branch

**Description:** Add a read-only `scripts/upstream-drift.sh` that, for each skill, compares the tree at the merge-base, at `upstream/main` and at `HEAD`.
It labels each skill untouched, upstream-only (adopt wholesale with `git checkout upstream/main -- skills/<name>`), fork-only, or changed on both sides (hand merge), and prints the version gap.
Set `rerere.enabled` and record the last triaged upstream SHA so "59 behind" becomes a count of untriaged commits.
Use the first run to settle the open overlap between `skills/diagnosing-bugs/SKILL.md` (reads `CONTEXT.md` and ADRs, referenced by no other skill) and `skills/systematic-debugging/SKILL.md`.
**Axis:** Fork hygiene and upstream drift
**Basis:** `direct:` from merge-base `d884ae0`, six skills are upstream-only and nine are changed on both sides, so most of the 59 commits need no merge work. `rerere` is unset.
Upstream's release notes mention "skills that better survive compaction" (7.0.1), "leaner plans from writing-plans" (6.4.2) and a rebuilt `brainstorming` (7.0.0), which touch the fork's open pains.
Cherry-picks are currently tracked by hand by PR number (`#2125`, `#2063`, `#2024`).
`external:` no standard fork-sync procedure exists for this project; the pattern is an upstream remote plus fetch and rebase.
**Rationale:** Drift has no tooling, and the gap grows with each upstream release.
The per-skill view turns an unapproachable rebase into a short worklist and shows which upstream rewrites collide with fork edits.
**Downsides:** Skill-level hashes miss changes to shared files such as `hooks/` and `scripts/`, so those need a second pass.
The nine both-changed skills still need manual merges.
**Confidence:** 85%
**Complexity:** Low

### 4. One `check-all.sh` as the fork's gate, starting by fixing the stale catalog

**Description:** Add `scripts/check-all.sh` that runs both generators' `--check` modes, `scripts/check-skill-refs.sh`, `scripts/lint-shell.sh`, and the deterministic suites in `tests/hooks`, `tests/shell-lint` and `tests/skill-catalog`.
Offer an opt-in `.githooks/pre-commit` that calls it, enabled with `git config core.hooksPath .githooks`.
Regenerate the README catalog first and update the hardcoded count of 18 in `tests/skill-catalog/test-generate-skill-catalog.sh`.
Keep tests that launch Claude sessions out of it.
**Axis:** Verification and testing of skills
**Basis:** `direct:` `scripts/generate-skill-catalog.sh --check` fails today with ten skills missing.
`scripts/check-skill-refs.sh:19-21` says "No CI wiring — run by hand before committing a skill edit", and no runner or doc references the hook, shell-lint or catalog tests.
Three earlier specs record "no CI wiring" as a decision, and a local aggregator does not conflict with it.
**Rationale:** The fork already owns the guards but nothing runs them, which is how the catalog went stale.
One command and an optional commit hook make the existing protection effective at no new dependency.
**Downsides:** A pre-commit gate adds friction to every commit and fails until the catalog is regenerated.
Shell lint needs `shellcheck`, which is now installed locally but not guaranteed elsewhere.
**Confidence:** 85%
**Complexity:** Low

### 5. A trigger-regression corpus on `claude plugin eval`, replacing the missing `evals/`

**Description:** Check in a small set of should-trigger and should-not-trigger prompts per model-invoked skill, including the dbt and SQL phrasings actually used, graded with `tool_used: Skill` and `regex`.
Run it with `--ablation none`, `--max-cost-usd` and `--no-publish` before and after description edits, routing-table changes and upstream adoptions.
Rewrite `docs/testing.md` and the two stale test headers to point at it and delete the references to the absent harness.
**Axis:** Verification and testing of skills
**Basis:** `direct:` `docs/testing.md:6,23` and the headers of `tests/claude-code/test-worktree-native-preference.sh` and `tests/claude-code/test-subagent-driven-development-integration.sh` cite an `evals/` directory that does not exist, and `tests/explicit-skill-requests` is the only trigger testing present.
`external:` the official `claude plugin eval` command exists in this install (2.1.322), with `init`, `regex`, `tool_used`, `tool_order` and `file_exists` graders, a cost ceiling, and normal Claude Code credentials; its docs say a failing `tool_used: Skill` with a near-zero baseline gap usually means the description does not match the prompt's wording.
**Rationale:** Triggering reliability is the fork's core promise and is never measured, so description edits ship blind.
A corpus is also the safety net that would make any future trimming of the always-loaded text or removal of overlapping skills a measured decision.
**Downsides:** Under the default `with-without` ablation, `tool_used: Skill` is not scored, so the free-grader version only works with `--ablation none` and cannot show a gain over no plugin; that needs the paid `llm` or `baseline` graders.
Runs count against plan usage, and the report publishes to claude.ai unless `--no-publish` is passed.
**Confidence:** 65%
**Complexity:** Medium

### 6. Make skills' declared trigger phrases a contract that one hook enforces

**Description:** Generalise `hooks/wrap-up-nudge` from one hard-coded skill to every `skills/*/SKILL.md` that has a `<trigger_phrases>` block, nudging `superpowers:<name>` on a match.
Reformat the `compound-learnings` block at `skills/compound-learnings/SKILL.md:714` to one phrase per line so it parses, curate its phrases, and add a parse check to the hook tests.
Have the nudge say "consider" for large skills, and decide whether a once-per-session marker is worth the state it adds.
**Axis:** Triggering and enforcement
**Basis:** `direct:` `hooks/wrap-up-nudge` reads only `skills/compound-memory/SKILL.md` and hard-codes its message.
The `compound-learnings` block is on one line and the parser's `^- "` pattern prints nothing for it, so that skill's documented auto-invoke is inert.
`external:` one author's roughly 200 activation tests report about 20% for a plain auto-trigger against 80-84% with a hook-based nudge; this is a single source and unconfirmed.
**Rationale:** The repo already states the convention ("read from the skill itself so the two cannot drift"), and extending it makes every later skill's deterministic trigger a matter of adding a block of text.
**Downsides:** Only two skills carry a block today, so the generalisation is partly premature, and `compound-learnings` is 9,837 words, so a false positive on phrases like "that worked" is expensive.
The hook is stateless today, so a once-per-session guard is new state.
**Confidence:** 60%
**Complexity:** Low

### 7. Give `compound-learnings` a read side and a place to write

**Description:** Add the two small hookups the integration spec called highest value and then deferred: `systematic-debugging` searches the solutions store before root-cause analysis, and `finishing-a-development-branch` ends with a prompt asking whether a learning is worth capturing.
Both should do nothing when the store is absent.
Define one resolution rule for where the store lives, defaulting to `docs/solutions/` and overridable, so learnings from read-only work repos can land in the writable notes vault instead of in repos the workspace rules forbid editing.
If neither hookup is wanted, the alternative is retiring the skill.
**Axis:** Memory and knowledge compounding
**Basis:** `direct:` `docs/specs/2026-07-19-gstack-compound-skills-integration-design.md` (around lines 80-91) calls the debugging consult "the single highest-value hookup", says the store never fills without a closing prompt, and defers both to a later phase that did not happen.
`docs/solutions/` does not exist, `skills/compound-learnings/SKILL.md` is 741 lines, and the workspace rules make every repo read-only except `core_code/`, which conflicts with the skill writing into whichever repo it runs in.
**Rationale:** The write side was ported and the read side was not, so the skill's loop has no consumer and nothing to compound against.
**Downsides:** It needs a user decision on whether the store should exist at all, and seeding it from `TROUBLESHOOTING.md` would hold the fork's own incidents rather than the user's work learnings.
`CONCEPTS.md` was skipped by decision and is not part of this.
**Confidence:** 50%
**Complexity:** Medium

---

## Rejection Summary

| # | Idea | Reason Rejected |
|---|------|-----------------|
| 1 | Event-bound nudge on `git commit`, `git push` and `gh pr create` | Fires rarely because commits only happen on explicit request, "done" has usually been claimed before then, and it overlaps `verification-before-completion` and the commit skill. The `if: "Bash(git *)"` filter avoids a spawn per call, but the trigger is still too narrow; reuse the router from idea 6 if it is wanted later. |
| 2 | Slim or replace the `session-start` injection | The injection is about 1.4k tokens per session, the saving is small against the risk to enforcement, it reverses the 2026-07-20 routing-table decision, and it widens merge conflicts in `skills/using-superpowers/SKILL.md`. Revisit once idea 5 exists to measure it. |
| 3 | Ratcheting skill-budget linter | A baseline of 20 of 28 skills over 500 words is mostly noise, and descriptions total only 4.7 KB, far from the 1% listing budget. |
| 4 | Imported-skill audit | Sound but small; folded into idea 3's first run, since `diagnosing-bugs` against `systematic-debugging` is the real decision and `grill-me` already costs nothing in the listing. |
| 5 | Capture memory at the moment of correction | Auto Memory already saves corrections, so this risks double saves, and short prompts containing "no" or "don't" are common, so it is noisy. |
| 6 | "Retire when:" line on project memories | The stale-entry check already exists and names "PR merged", and the line would only cover memories written through the skill, not Auto Memory's own saves. |
| 7 | Hook self-test at session start | `tests/hooks/test-memory-hooks.sh` already asserts that the real phrases nudge, so a broken phrase block fails the tests, and a runtime check adds cost for little. |
| 8 | Incident-to-lint script | One of its three checks (a workflow clause after " - ") contradicts repo convention, since 10 of 28 descriptions use that separator; the missing-`model:` check could stand alone later. |
| 9 | Skill-feedback inbox | Adds a new store for a solo user with low volume, and Auto Memory already has a feedback type. |
| 10 | Path-scoped rules as the memory store | Auto Memory is already per-project, so the premise is partly wrong; it contradicts the "no new storage location" decision, and `paths:` for user-level rules is documented without an example. |
| 11 | Two invocation tiers via `disable-model-invocation` | Docs confirm the description leaves the listing, but the saving is about 1 KB, six skills already carry the flag, and it would block the skill-tool invocation that the wrap-up nudge relies on. |
| 12 | Split the fork into two plugins along the upstream seam | All nine both-changed skills sit in the core set so merges still conflict, the hooks and routing table couple the two plugins, and the docs do not address two plugins sharing one repo root. |
| 13 | Skill census from transcripts | Conflicts with the decision against transcript scanning on PHI-adjacent data, and `/skill-doctor` may already report usage. |
| 14 | Description-collision matrix | Rests on one unconfirmed source for keyword-overlap activation, the shared "Use when" boilerplate makes overlap noisy, and there are only 28 skills. |
| - | axis: Context and token cost | No survivors: measured always-loaded cost is small (5.4 KB injection, 4.7 KB of descriptions), and the available trims reverse deliberate decisions or put enforcement at risk. A deliberate gap, not an oversight. |
