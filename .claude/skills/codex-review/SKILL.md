---
name: codex-review
description: Get an independent second opinion from OpenAI Codex CLI on a plan, diff, spec, or Claude's last response. Use when the user asks to "get a second opinion", "have codex review", "cross-check with codex", or wants adversarial review of Claude's output. Argument is one of plan|diff|spec|last-response (default last-response).
argument-hint: "[plan|diff|spec|last-response]"
user-invocable: true
allowed-tools:
  - Read
  - Write
  - Bash(codex *)
  - Bash(command -v *)
  - Bash(ls *)
  - Bash(fd *)
  - Bash(mktemp *)
  - Bash(cat *)
  - Bash(printf *)
---

# /codex-review — Independent second opinion from Codex CLI

Argument: `$ARGUMENTS` — one of `plan` | `diff` | `spec` | `last-response`. Default `last-response`.

Never fall back to reviewing Claude's own output if Codex fails. If Codex can't run, say so and stop.

## 1. Preflight

Run in order. Stop cleanly on first failure:

```bash
command -v codex >/dev/null 2>&1 || { echo "codex CLI not found. Install: https://github.com/openai/codex"; exit 0; }
codex login status 2>&1 | grep -qi "logged in" || { echo "codex not logged in. Run: codex login"; exit 0; }
```

## 2. Resolve target

- **`last-response`** (default): identify your *previous substantive assistant turn* (the last turn with user-facing prose — skip turns that are pure tool calls or tool results). Write that prose verbatim to a temp file via the Write tool: `$(mktemp -t codex-review).md`. Record the path as `$TARGET_FILE`.
- **`plan`**: if there is an active in-conversation plan, write it to a temp file as above. Otherwise pick the newest file under `./.claude/plans/` (`ls -t ./.claude/plans/*.md 2>/dev/null | head -1`). If neither exists, report "no plan found" and stop.
- **`spec`**: pick the newest `spec.md` under `./specs/` (`fd -t f 'spec\.md$' ./specs 2>/dev/null | xargs ls -t 2>/dev/null | head -1`). If none, stop.
- **`diff`**: no file needed — Codex reads the repo directly via `codex review --uncommitted`.

## 3. Build rubric (skip for `diff`)

The `diff` target uses `codex review`'s built-in review prompt — do **not** pass a custom rubric there (`--uncommitted` is mutually exclusive with `[PROMPT]` and will error).

For `plan` | `spec` | `last-response`, write this rubric to `$(mktemp -t codex-rubric).txt`:

```
You are an adversarial reviewer giving a second opinion. Be terse. Do not restate what is correct.

Check, in order:
1. Correctness — logic errors, off-by-one, wrong APIs, broken invariants.
2. Missing edge cases — nulls, empty inputs, concurrent writes, partial failures, auth gaps.
3. Simpler alternatives — is there a shorter, more conventional, or better-supported approach?
4. Risk — blast radius, reversibility, data loss, security implications.

Output format: 4 sections with those exact headings. Skip a section if you have nothing material. No preamble, no summary, no praise.
```

## 4. Invoke Codex

Use a single Bash call with 600000ms timeout. Capture stdout and exit code. Do **not** pass `-c model=...` — rely on the user's `~/.codex/config.toml` defaults.

- **`diff`**:
  ```bash
  codex review --uncommitted
  ```
- **`plan` | `spec` | `last-response`**:
  ```bash
  { printf '=== CONTENT TO REVIEW ===\n'; cat "$TARGET_FILE"; printf '\n\n=== REVIEW INSTRUCTIONS ===\n'; cat "$RUBRIC_FILE"; } \
    | codex exec --sandbox read-only --skip-git-repo-check -
  ```

Pass all content via stdin. Never put file contents on argv.

## 5. Emit review

On exit code `0`:

```
### Codex Review

<codex stdout verbatim — no edits, no paraphrase>
```

On non-zero exit or timeout:

```
### Codex Review (FAILED)

Codex exited with status <N>. Stderr tail:
<last 20 lines of stderr>
```

Stop after emitting failure. Do not substitute your own review.

## 6. Ask before reconciling

After a successful review, end your turn with one question to the user:

> Want me to reconcile — decide which points to adopt, reject, or defer?

Only if the user says yes, produce a `### Reconciliation` section with three bullet lists: **Adopt**, **Reject** (each with a one-line reason), **Defer** (each with a one-line reason to revisit later). Do not rubber-stamp Codex; reject points that are wrong or off-scope.
