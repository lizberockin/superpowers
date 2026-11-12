# Contributing

Superpowers is a library of markdown-defined agent skills (each a `SKILL.md`
plus optional `references/`). Skills are the primary way to contribute to
this repo.

## Adding or editing a skill

Start with [`skills/writing-skills/SKILL.md`](skills/writing-skills/SKILL.md)
— it defines the TDD-for-skills methodology this repo requires: run a
baseline scenario with a naive agent before writing anything, write the
skill to close the observed gap, then verify with pressure-test subagents.
Skills that skip this process tend to under- or over-specify what they're
teaching.

## Reporting issues

Open an issue on this repo's GitHub page with a description of the problem
and, if applicable, the prompt or scenario that triggered it.

## Checks before you commit

Run `scripts/check-all.sh` to run every deterministic guard: the generated skill catalog and routing table, skill cross-references, shell lint on changed files, the test suites, plugin manifest validation, and that the plugin manifests do not pin a `version` (so installs keep tracking new commits). To run it automatically before each commit in your clone, opt in with `git config core.hooksPath .githooks`.
