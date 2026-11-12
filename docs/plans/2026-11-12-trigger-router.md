# Trigger Router Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make one `UserPromptSubmit` hook enforce every skill's declared `<trigger_phrases>`, and make `compound-learnings`' inert trigger block actually work.

**Architecture:** Rename `hooks/wrap-up-nudge` to `hooks/trigger-nudge` and generalise it to scan every `skills/*/SKILL.md` for a phrase block, naming the matching skill and choosing "invoke now" or "consider" wording from an optional `mode="consider"` attribute on the skill's `<auto_invoke>` tag. Tests use a throwaway plugin root of fixture skills plus end-to-end assertions against the real skills.

**Tech Stack:** bash (3.2-compatible), awk, sed, grep, node (already used by the existing tests for JSON).

Spec: `docs/specs/2026-11-12-trigger-router-design.md`.

## Global Constraints

- Hook behaviour that must not change: reads the hook JSON from stdin (`prompt` via `jq`, falling back to the raw input when `jq` is absent); exits 0 with no output for empty prompts, for prompts longer than 120 characters (`MAX_PROMPT_CHARS=120`), and when nothing matches; matches phrases case-insensitively on word boundaries; emits `hookSpecificOutput` JSON with `hookEventName` `UserPromptSubmit` and `additionalContext`.
- New hook behaviour: scan every `skills/*/SKILL.md` (relative to the hook's own location, alphabetical order) that contains `<trigger_phrases>`; the first matching phrase wins; the nudge names the skill's directory name as `superpowers:<name>`; phrases are one `- "phrase"` per line between `<trigger_phrases>` and `</trigger_phrases>`; a block with no parseable phrase lines is silently ignored.
- Wording: without a `mode` attribute on the skill's `<auto_invoke ...>` tag, the nudge says to invoke the skill now, before the final reply; with `mode="consider"` it says to consider invoking it if it applies; any other mode value behaves as the default.
- `skills/compound-learnings/SKILL.md`: reformat the block at line 714 to multi-line, one phrase per line, with `mode="consider"`; keep exactly three phrases (`it's fixed`, `working now`, `problem solved`), dropping `that worked`; leave the `<manual_override>` text unchanged.
- No state, no once-per-session marker, no new hooks or events; no change to `pre-compact`, `session-start`, or the compound-memory scan logic; no phrases for any other skill; no change to `skills/writing-skills/SKILL.md`.
- Per the user's standing rule, do not commit unless the user asks, and use `mv` (not `git mv`) for the rename so the index is untouched. Do not run `git add`, `git commit`, `git stash`, `git checkout` or `git reset`. Where the usual plan format has a commit step, the last step of each task is a checkpoint that leaves changes uncommitted.
- Commits in this repo use only the identity configured in the repo-local git config (not relevant until the user asks for a commit).
- Work on branch `feat/trigger-router` in `$HOME/code/superpowers`. Run all commands from that directory. Run tests with stdin closed (`</dev/null`).

---

### Task 1: Generalise the hook (rename, scan every skill, `mode` wording)

**Files:**
- Modify: `tests/hooks/test-memory-hooks.sh`
- Rename and rewrite: `hooks/wrap-up-nudge` to `hooks/trigger-nudge`
- Modify: `hooks/hooks.json`
- Modify: `skills/compound-memory/SKILL.md` (one sentence)

**Interfaces:**
- Produces: `hooks/trigger-nudge` (executable) reading `skills/*/SKILL.md` relative to its own location; nudge text containing `superpowers:<name>` and either `Invoke it now` (default) or `Consider invoking` (`mode="consider"`); test helpers `make_plugin_root`, `run_root_hook`, `assert_root_context`, `assert_root_silent` in `tests/hooks/test-memory-hooks.sh`.

- [ ] **Step 1: Update and extend the tests (failing first)**

In `tests/hooks/test-memory-hooks.sh`:

(a) Replace every occurrence of `wrap-up-nudge` with `trigger-nudge` (lines 27, 37, 45 and 53 at the time of writing: the two `run_hook` calls inside `assert_nudge` and `assert_silent`, the `echo "wrap-up-nudge (UserPromptSubmit)"` heading, and the empty-stdin check).

(b) Insert this block immediately above the line `echo "pre-compact (PreCompact)"`:

```bash
make_plugin_root() {
    local root="$1" s
    mkdir -p "$root/hooks"
    for s in alpha beta broken zeta; do
        mkdir -p "$root/skills/$s"
    done
    cp "$HOOKS/trigger-nudge" "$root/hooks/trigger-nudge"
    cat > "$root/skills/alpha/SKILL.md" <<'EOF'
---
name: alpha
description: fixture
---
<auto_invoke>
<trigger_phrases>
- "alpha phrase"
</trigger_phrases>
</auto_invoke>
EOF
    cat > "$root/skills/beta/SKILL.md" <<'EOF'
---
name: beta
description: fixture
---
<auto_invoke mode="consider">
<trigger_phrases>
- "beta phrase"
</trigger_phrases>
</auto_invoke>
EOF
    cat > "$root/skills/broken/SKILL.md" <<'EOF'
---
name: broken
description: fixture
---
<auto_invoke> <trigger_phrases> - "broken phrase" </trigger_phrases> </auto_invoke>
EOF
    cat > "$root/skills/zeta/SKILL.md" <<'EOF'
---
name: zeta
description: fixture
---
<auto_invoke>
<trigger_phrases>
- "zeta phrase"
</trigger_phrases>
</auto_invoke>
EOF
}

run_root_hook() {
    local root="$1" prompt="$2"
    node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt" |
        env -i PATH="${PATH:-}" HOME="${TMPDIR:-/tmp}" bash "$root/hooks/trigger-nudge"
}

assert_root_context() {
    local root="$1" prompt="$2" skill="$3" wording="$4" out
    out="$(run_root_hook "$root" "$prompt")"
    if [[ -n "$out" ]] && printf '%s' "$out" | context_of | grep -q "superpowers:$skill" &&
        printf '%s' "$out" | context_of | grep -q "$wording"; then
        pass "'$prompt' nudges superpowers:$skill ($wording)"
    else
        fail "'$prompt' should nudge superpowers:$skill with '$wording'"
    fi
}

assert_root_silent() {
    local root="$1" prompt="$2" out
    out="$(run_root_hook "$root" "$prompt")"
    if [[ -z "$out" ]]; then
        pass "silent on: $prompt"
    else
        fail "expected silence on: $prompt"
    fi
}

echo "trigger-nudge across several skills"
plugin_root="$(mktemp -d)"
trap 'rm -rf "$plugin_root"' EXIT
make_plugin_root "$plugin_root"
assert_root_context "$plugin_root" "ok alpha phrase now" alpha "Invoke it now"
assert_root_context "$plugin_root" "BETA PHRASE" beta "Consider invoking"
assert_root_context "$plugin_root" "zeta phrase" zeta "Invoke it now"
assert_root_context "$plugin_root" "zeta phrase and alpha phrase" alpha "Invoke it now"
assert_root_silent "$plugin_root" "broken phrase"
assert_root_silent "$plugin_root" "nothing relevant here"
long_prompt="alpha phrase $(printf 'x%.0s' $(seq 1 130))"
assert_root_silent "$plugin_root" "$long_prompt"

```

(c) Insert this block immediately above the line `if [[ "$FAILURES" -gt 0 ]]; then` (after the existing `hooks.json` section):

```bash
echo "hooks.json points at hooks that exist"
missing="$(node -e '
const fs = require("fs"), path = require("path");
const hooks = require(process.argv[1]).hooks;
const missing = [];
for (const groups of Object.values(hooks)) for (const g of groups) for (const h of g.hooks) {
  const m = /run-hook\.cmd"?\s+(\S+)/.exec(h.command);
  if (m && !fs.existsSync(path.join(process.argv[2], m[1]))) missing.push(m[1]);
}
console.log(missing.join(","));
' "$HOOKS/hooks.json" "$HOOKS")"
if [[ -z "$missing" ]]; then
    pass "every hook named in hooks.json exists"
else
    fail "hooks.json names missing hooks: $missing"
fi

```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/hooks/test-memory-hooks.sh </dev/null; echo "exit=$?"`
Expected: non-zero exit. The run stops at the first hook call because `hooks/trigger-nudge` does not exist yet (`bash: .../hooks/trigger-nudge: No such file or directory`); there is no `STATUS: PASSED`.

- [ ] **Step 3: Rename the hook and write the new implementation**

Run: `mv hooks/wrap-up-nudge hooks/trigger-nudge`

Then replace the entire contents of `hooks/trigger-nudge` with exactly this (the file stays executable):

```bash
#!/usr/bin/env bash
# UserPromptSubmit hook: deterministic skill triggers.
# A skill declares trigger phrases between <trigger_phrases> and </trigger_phrases>,
# one `- "phrase"` per line, inside an <auto_invoke> block. A short prompt containing
# one of them (case-insensitive, on word boundaries) nudges toward that skill. An
# optional mode="consider" attribute on the <auto_invoke> tag softens the wording.
# Phrases are read from the skills themselves so the two cannot drift.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../skills"
MAX_PROMPT_CHARS=120

input="$(cat)"

if command -v jq >/dev/null 2>&1; then
  prompt="$(printf '%s' "$input" | jq -r '.prompt // empty' 2>/dev/null || true)"
else
  prompt="$input"
fi

[ -n "$prompt" ] || exit 0
[ "${#prompt}" -le "$MAX_PROMPT_CHARS" ] || exit 0

emit() {
  local name="$1" mode="$2" phrase="$3" context
  if [ "$mode" = "consider" ]; then
    context="The user's message ('${phrase}') matches a trigger for superpowers:${name}. Consider invoking it if it applies."
  else
    context="The user's message ('${phrase}') matches a trigger for superpowers:${name}. Invoke it now, before your final reply."
  fi
  printf '{\n  "hookSpecificOutput": {\n    "hookEventName": "UserPromptSubmit",\n    "additionalContext": "%s"\n  }\n}\n' "$context"
}

lower="$(printf '%s' "$prompt" | tr '[:upper:]' '[:lower:]')"

for skill_file in "$SKILLS_DIR"/*/SKILL.md; do
  [ -r "$skill_file" ] || continue
  grep -q '<trigger_phrases>' "$skill_file" || continue

  phrases="$(awk '/<trigger_phrases>/{on=($0 !~ /<\/trigger_phrases>/);next} /<\/trigger_phrases>/{on=0} on && /^- "/{sub(/^- "/,"");sub(/"$/,"");print}' "$skill_file")"
  [ -n "$phrases" ] || continue

  name="$(basename "$(dirname "$skill_file")")"
  mode="$(grep -o '<auto_invoke[^>]*>' "$skill_file" | head -n 1 | sed -n 's/.*mode="\([a-z]*\)".*/\1/p' || true)"

  while IFS= read -r phrase; do
    [ -n "$phrase" ] || continue
    p="$(printf '%s' "$phrase" | tr '[:upper:]' '[:lower:]')"
    if printf '%s' "$lower" | grep -qE "(^|[^[:alnum:]])${p//./\\.}([^[:alnum:]]|$)"; then
      emit "$name" "$mode" "$phrase"
      exit 0
    fi
  done <<< "$phrases"
done

exit 0
```

- [ ] **Step 4: Point `hooks.json` and `compound-memory` at the new name**

In `hooks/hooks.json`, change the UserPromptSubmit command from

```
"command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" wrap-up-nudge",
```

to

```
"command": "\"${CLAUDE_PLUGIN_ROOT}/hooks/run-hook.cmd\" trigger-nudge",
```

In `skills/compound-memory/SKILL.md`, in the paragraph beginning `Two hooks make this deterministic`, replace the text `` `wrap-up-nudge` (UserPromptSubmit) matches the phrases above `` with `` `trigger-nudge` (UserPromptSubmit) matches the phrases above ``. Change nothing else in that file.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `bash tests/hooks/test-memory-hooks.sh </dev/null; echo "exit=$?"`
Expected: every line `[PASS]`, ending `STATUS: PASSED` and `exit=0`. The new lines include `'ok alpha phrase now' nudges superpowers:alpha (Invoke it now)`, `'BETA PHRASE' nudges superpowers:beta (Consider invoking)`, `'zeta phrase and alpha phrase' nudges superpowers:alpha`, `silent on: broken phrase`, and `every hook named in hooks.json exists`.

- [ ] **Step 6: Lint and related tests**

Run:

```bash
bash scripts/lint-shell.sh hooks/trigger-nudge tests/hooks/test-memory-hooks.sh; echo "lint exit=$?"
bash tests/hooks/test-session-start.sh </dev/null | tail -1
```

Expected: `lint exit=0`; the session-start test ends `STATUS: PASSED`. Fix any ShellCheck warning in the new files (not the lint config) and re-run Steps 5 and 6.

- [ ] **Step 7: Checkpoint (do not commit)**

Run: `git status --short`
Expected: `hooks/wrap-up-nudge` shown as deleted, `hooks/trigger-nudge` as untracked, and `hooks/hooks.json`, `skills/compound-memory/SKILL.md`, `tests/hooks/test-memory-hooks.sh` as modified (plus the spec and this plan untracked). Leave everything uncommitted.

---

### Task 2: Make `compound-learnings`' block work, with end-to-end checks on the real skills

**Files:**
- Modify: `tests/hooks/test-memory-hooks.sh`
- Modify: `skills/compound-learnings/SKILL.md` (the block near line 714)
- Modify: `docs/specs/2026-08-02-compound-memory-design.md` (append one note)

**Interfaces:**
- Consumes: `hooks/trigger-nudge` and the test helpers `run_hook`, `context_of`, `assert_silent` from Task 1 and the existing file.
- Produces: the real `skills/compound-learnings/SKILL.md` declares a parseable `<auto_invoke mode="consider">` block with three phrases; test helper `assert_nudge_skill`.

- [ ] **Step 1: Add the end-to-end tests (failing first)**

In `tests/hooks/test-memory-hooks.sh`, insert this block immediately above the line `echo "hooks.json points at hooks that exist"` (the heading added in Task 1):

```bash
assert_nudge_skill() {
    local prompt="$1" skill="$2" wording="$3" out
    out="$(run_hook trigger-nudge "$(node -e 'console.log(JSON.stringify({prompt:process.argv[1]}))' "$prompt")")"
    if [[ -n "$out" ]] && printf '%s' "$out" | context_of | grep -q "superpowers:$skill" &&
        printf '%s' "$out" | context_of | grep -q "$wording"; then
        pass "real skills: '$prompt' nudges superpowers:$skill ($wording)"
    else
        fail "real skills: '$prompt' should nudge superpowers:$skill with '$wording'"
    fi
}

echo "every real skill that declares trigger phrases has a parseable block"
for skill_file in "$REPO_ROOT"/skills/*/SKILL.md; do
    grep -q '<trigger_phrases>' "$skill_file" || continue
    skill_name="$(basename "$(dirname "$skill_file")")"
    first_phrase="$(awk '/<trigger_phrases>/{on=($0 !~ /<\/trigger_phrases>/);next} /<\/trigger_phrases>/{on=0} on && /^- "/{sub(/^- "/,"");sub(/"$/,"");print;exit}' "$skill_file")"
    if [[ -z "$first_phrase" ]]; then
        fail "$skill_name: <trigger_phrases> block has no parseable phrase lines"
        continue
    fi
    assert_nudge_skill "$first_phrase" "$skill_name" "superpowers:$skill_name"
done

echo "compound-learnings triggers"
assert_nudge_skill "it's fixed" compound-learnings "Consider invoking"
assert_nudge_skill "ok working now, thanks" compound-learnings "Consider invoking"
assert_nudge_skill "problem solved" compound-learnings "Consider invoking"
assert_silent "that worked"

```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `bash tests/hooks/test-memory-hooks.sh </dev/null; echo "exit=$?"`
Expected: exit 1 with `STATUS: FAILED`. The new failures include `compound-learnings: <trigger_phrases> block has no parseable phrase lines`, and `real skills: 'it's fixed' should nudge superpowers:compound-learnings with 'Consider invoking'` (plus the `working now` and `problem solved` ones). `silent on: that worked` already passes (the block is inert today). All Task 1 assertions still `[PASS]`.

- [ ] **Step 3: Reformat the `compound-learnings` block**

In `skills/compound-learnings/SKILL.md`, replace this exact line (near line 714):

```
<auto_invoke> <trigger_phrases> - "that worked" - "it's fixed" - "working now" - "problem solved" </trigger_phrases>
```

with exactly these lines:

```
<auto_invoke mode="consider">
<trigger_phrases>
- "it's fixed"
- "working now"
- "problem solved"
</trigger_phrases>
```

Leave the blank line and the following `<manual_override> ... </manual_override> </auto_invoke>` line exactly as they are, and change nothing else in the file.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `bash tests/hooks/test-memory-hooks.sh </dev/null; echo "exit=$?"`
Expected: every line `[PASS]`, ending `STATUS: PASSED` and `exit=0`. The output includes `real skills: 'that's everything' nudges superpowers:compound-memory`, `real skills: 'it's fixed' nudges superpowers:compound-learnings (Consider invoking)`, and `silent on: that worked`.

- [ ] **Step 5: Record the rename in the earlier design note**

Append this line to the very end of `docs/specs/2026-08-02-compound-memory-design.md` (after a blank line), leaving everything above it unchanged:

```
Later note (2026-11-12): `wrap-up-nudge` was renamed `trigger-nudge` and generalised to read every skill's `<trigger_phrases>` block; see `docs/specs/2026-11-12-trigger-router-design.md`.
```

- [ ] **Step 6: Verify the rest still holds**

Run:

```bash
bash scripts/lint-shell.sh hooks/trigger-nudge tests/hooks/test-memory-hooks.sh; echo "lint exit=$?"
bash scripts/check-skill-refs.sh | tail -1
bash tests/hooks/test-session-start.sh </dev/null | tail -1
bash scripts/generate-routing-table.sh --check >/dev/null 2>&1; echo "routing check exit=$?"
```

Expected: `lint exit=0`; `All ... skill references resolve.`; the session-start test `STATUS: PASSED`. The routing check exits 1 on this branch (a known pre-existing drift fixed on a different branch); that is expected and not caused by this work, so report the value without trying to fix it.

- [ ] **Step 7: Checkpoint (do not commit)**

Run: `git status --short`
Expected: `hooks/wrap-up-nudge` deleted, `hooks/trigger-nudge` untracked, and `hooks/hooks.json`, `skills/compound-memory/SKILL.md`, `skills/compound-learnings/SKILL.md`, `tests/hooks/test-memory-hooks.sh`, `docs/specs/2026-08-02-compound-memory-design.md` modified (plus the new spec and this plan untracked). Leave everything uncommitted and report the Step 4 and Step 6 outputs.

---

## Post-review amendments (applied after the plan was executed)

The final whole-branch review found that "first match wins" combined with alphabetical order (`compound-learnings` before `compound-memory`) made "it's fixed, done for now" lose `compound-memory`'s firm "invoke now" nudge. The user chose to nudge every matching skill, so the hook now collects one nudge per matching skill and emits them in one `additionalContext`; the spec was amended. Four cheap hardening fixes landed with it: the phrase parser tolerates CRLF line endings, requires the opening tag to start its line, and the fixtures now exercise the one-line-block guard, an unrecognised mode value, a CRLF skill and a prose mention of the tag. The code blocks above are the plan as first written.
