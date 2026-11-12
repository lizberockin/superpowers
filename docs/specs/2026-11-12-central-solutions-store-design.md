# Central solutions store: give `compound-learnings` a safe place to write and a reader

## Goal

Make `compound-learnings` write its solution docs to a central store in the user's notes vault instead of into whichever repository the session happens to be in, give debugging a step that reads that store, and switch off three behaviours of the skill that conflict with the user's decisions and rules.

## Problem

`skills/compound-learnings/SKILL.md` (about 9,800 words) writes `docs/solutions/<category>/<file>.md` inside the current repository, creating the directory with `mkdir -p` (line 314). The user's workspace rules make every work repository read-only except the `core_code/` notes vault, and the data is sensitive, so the default conflicts with the rule. `docs/solutions/` does not exist in the fork either.

Nothing reads the store. The 2026-07-19 gstack integration design called a `systematic-debugging` consult "the single highest-value hookup" and deferred it to a later phase that never happened.

Three more behaviours of the skill conflict with explicit decisions:

- In Full mode it creates `CONCEPTS.md` when a qualifying term surfaces (Phase 2.4, around line 342), although the user decided to skip `CONCEPTS.md`.
- It bundles scripts that discover and read session transcripts under `~/.claude/projects` (`scripts/session-history/`), and its own text is inconsistent about whether this needs opt-in (a line in Support Files says opt-in; the Execution Strategy says an automatic probe). Transcripts are PHI-adjacent and the user has ruled out transcript scanning.
- A Discoverability Check proposes edits to a repository's `AGENTS.md` or `CLAUDE.md`, which are sibling repositories the user treats as read-only.

The `trigger-nudge` hook (built separately) now steers toward this skill on "it's fixed", "working now" and "problem solved", so the skill is invoked more often than before.

## Design

### Store location

One rule, stated in the skill and in the consult step:

- If the environment variable `SUPERPOWERS_SOLUTIONS_ROOT` is set, the store is `$SUPERPOWERS_SOLUTIONS_ROOT/<repo-name>/solutions/`, where `<repo-name>` is the folder name of the main working tree, derived with `basename "$(cd "$(git rev-parse --git-common-dir)/.." && pwd)"` so that it is the same from a subdirectory and from a linked worktree (`git rev-parse --show-toplevel` would return the worktree's own, often branch-named, folder and scatter one project's learnings), or `_general` outside any repository. The variable must hold an absolute path: Claude Code's `settings.json` env values are not tilde-expanded, and a relative or `~` path would make `mkdir -p` create directories inside the repository, so the skill stops and says so otherwise. For this user the value would be `/Users/<you>/code/core_code/docs`, giving `core_code/docs/<repo-name>/solutions/`.
- If it is not set, the store is `docs/solutions/` at the repository root (upstream behaviour); outside a repository with the variable unset, the skill stops and reports that no store can be resolved.
- Category subdirectories (for example `build-errors/`) nest under the store unchanged.
- Setting the variable means editing the user's `~/.claude/settings.json`; that is done last, with the user's explicit go-ahead, and is not part of the fork's code.

### Write side: `skills/compound-learnings/SKILL.md`

Because the skill is large and interwoven, make one authoritative addition plus small markers rather than rewriting phases:

- A new `## Fork Overrides` section before `## Purpose`, stating it takes precedence over everything below, with five items: the store location rule (naming the resolved directory `$SOLUTIONS_DIR`); never create or edit `CONCEPTS.md`; never search session history or read transcripts; never edit instruction files; and no patient data in a solution doc (identifiers, data values and row contents are never included; describe problems with schema, column and model names only).
- A one-line banner `> Disabled in this fork: see Fork Overrides. Skip this section.` under the headings of the four sections that the overrides switch off: `## CONCEPTS.md bootstrap requests`, the Phase 1 step `#### 4. **Session History** ...`, `### Phase 2.4: Vocabulary Capture` and `### Discoverability Check`.
- Short "disabled in this fork" prefixes on the other places that would otherwise still instruct the behaviour: the Execution Strategy paragraph beginning "Session history — an automatic probe in Full mode", the Phase 1 bullet beginning "Then run the internal session-history discovery/extraction/synthesis flow", and Lightweight mode steps 4 (vocabulary capture) and 5 (read-only discoverability check).
- The literal path instructions that would write or search outside the resolved store are changed to `$SOLUTIONS_DIR`: the `mkdir -p` and write steps (lines 314-315), the exact-path collision check in Lightweight mode (line 491), the "glob fresh every run" line (142), the related-docs search bullet (199) and its category-narrowing line (223). The resolved absolute `$SOLUTIONS_DIR` is also passed into every Phase 1 subagent prompt (the line that passes `{run_id}` and `{run_dir}`), together with the no-patient-data rule (Fork Override 5) and an instruction to read every `docs/solutions/` in the references as `$SOLUTIONS_DIR`, because subagents do not see the Fork Overrides; the write step redacts per Fork Override 5 first. A set-but-empty variable counts as set and must be an absolute path; outside a repository, where `git rev-parse --git-common-dir` fails, the repo name is `_general`.
- The places that still mention the disabled behaviours (Mode Detection and Execution Strategy text, the "What It Creates" list, the wait-for-Phase-1 line, the Lightweight-mode mention of `CONCEPTS.md`) get a short "disabled in this fork" marker, and a note under `## Success Output` tells the agent to skip the Session History, `CONCEPTS.md` and instruction-file lines in the output templates, so the overrides are not contradicted by passive text. Passive mentions elsewhere (Support Files, Common Mistakes, remaining template lines) are left to Fork Overrides 1-5.
- No change to the bundled scripts, `references/` or `assets/`; `scripts/session-history/` and the session-historian prompt stay in the repository, unused. `validate-doc-claims.py` degrades gracefully for a doc outside any git repository (it prints that path and SHA classification are skipped and still checks links and scaffold), so Phase 2.45 keeps working with the vault location, with reduced path and SHA checking.

### Read side: `skills/systematic-debugging/SKILL.md`

One short paragraph at the start of Phase 1, before the numbered steps: "Check for a known solution first." It states the same resolution rule, tells the agent to search the store for the error message or symptom, treats a match as evidence to verify against current code and not as a fix to apply (so the Iron Law is unchanged), and says to skip the step when the directory does not exist. This makes `systematic-debugging` a both-changed skill in the upstream drift report, so a future adoption of upstream's version means hand-merging this one paragraph.

### Vault side (outside the fork's code)

One line added to the vault index in `~/code/core_code/CLAUDE.md` pointing at `docs/<repo-name>/solutions/`, so sessions started from the vault know the store exists. This is the user's notes vault, which the workspace rules make read-write.

## Testing

`tests/solutions-store/test-solutions-store.sh`, written before the skill edits (red first), static checks over the prose plus one behavioural check:

- `compound-learnings` has a `## Fork Overrides` section containing the five numbered items and the variable name `SUPERPOWERS_SOLUTIONS_ROOT`.
- `systematic-debugging` contains the "Check for a known solution first" paragraph and the same variable name, and the variable name is identical in both skills.
- No `mkdir -p docs/solutions` and no unconverted write instruction (`docs/solutions/[category]/[filename].md` in the write step) remains in `compound-learnings`.
- The four disabling banners and the other disabled-in-this-fork markers are present at the expected places (counted, and the banner line directly follows each of the four headings).
- `scripts/validate-doc-claims.py` run on a throwaway doc outside any git repository prints the "not a git repository" notice and does not crash (exit code 0 or 1, never 2).
- `scripts/check-skill-refs.sh` still passes.

These are consistency guards, not evidence that agents follow the overrides: the fork has no skill-behaviour evaluation harness and the baseline pressure-testing that `writing-skills` asks for is not run. That is a known gap.

## Known limits

- The overrides are prose placed at the top of a large skill plus local markers; an agent could still follow older text deeper in the file. The markers are placed to make that unlikely, not impossible.
- The store lives in a vault that is not a git repository, so there is no history or diff for learnings.
- With the store outside any repository, `validate-doc-claims.py` cannot classify cited paths or commit SHAs.
- Only `systematic-debugging` consults the store; `diagnosing-bugs`, `writing-plans` and `brainstorming` do not.

## Non-goals

- No closing prompt in `finishing-a-development-branch`, no consults in other skills, no seeding of the store.
- No deletion of the session-history scripts and prompt; they are only switched off in the skill text.
- No edit of `~/.claude/settings.json` or of the vault index as part of the fork's code or its tests.
- No change to the `trigger-nudge` hook or to `compound-learnings`' trigger phrases.
