---
name: dependabot-review
description: >-
  Reviews Dependabot gem upgrade PRs for breaking changes, codebase impact, and merge readiness.
  Use when user pastes a Dependabot PR URL, asks about a gem version bump, or wants to audit open
  dependency PRs ("which dep PRs are safe to merge", "audit our deps", "check dependabot").
  WHEN NOT: Non-Dependabot PRs, npm/yarn upgrades, or general code review.
allowed-tools: Read, Bash, WebFetch, Grep, Glob
model: sonnet
effort: high
context: fork
agent: general-purpose
---

# Dependabot Gem Upgrade Review

Current repo: !`gh repo view --json nameWithOwner -q .nameWithOwner 2>/dev/null || echo "(unknown — run from inside the repo)"`

Review Dependabot PRs and give the developer a concise, scannable verdict: what changed upstream, what could break (and how to fix it), what each gem touches in the codebase, and whether to merge.

Trigger phrases for audit mode: "review all open dependabot PRs", "which dependabot PRs are ready to merge", "audit our dep upgrades", "go through the open dep PRs", "check dependabot", any request for a status/report on pending dependency updates. Trigger single-PR mode on any GitHub PR URL related to dependabot, gem upgrades, or "bump" in the title. If the intent is ambiguous, default to audit mode.

## Choosing a mode

Pick the mode based on what the user asked for:

- **Single-PR mode** — the user pasted a specific Dependabot PR URL or otherwise referenced one PR. Run the single-PR workflow below.
- **Audit mode** — the user asked about *all* open Dependabot PRs (phrases like "audit our deps", "review open dependabot PRs", "which dep upgrades are safe to merge"). Run the audit workflow. Do **not** ask the user to paste URLs — discover them with `gh`.

If the intent is ambiguous (e.g., "review dependabot"), default to audit mode since it's the superset and shows what's available.

## Audit workflow (multiple PRs)

### Step A1: Discover open Dependabot PRs

Determine the repo from the current working directory (`gh repo view --json nameWithOwner -q .nameWithOwner`). Then list open Dependabot PRs:

```bash
gh pr list --author "app/dependabot" --state open \
  --json number,title,url,createdAt,headRefName,labels \
  --limit 50
```

The `app/` prefix in the author filter is required — Dependabot authors as the bot account `app/dependabot`. If `gh` returns an empty list, tell the user "No open Dependabot PRs in <repo>." and stop.

Before diving into analysis, surface the scope to the user in one line: "Found N open Dependabot PRs. Analyzing each now…" — this sets expectations when there are many to crunch through.

### Step A2: Analyze each PR

For every PR returned, run the **single-PR workflow** (Steps 1-3 below) to gather bump type, changelog highlights, and codebase impact. Keep each analysis tight — you'll be producing per-PR sections for a combined report, not standalone documents.

You can fetch independent PRs in parallel where the tool call structure allows it.

### Step A3: Produce the consolidated report

Emit the report in this order:
1. A short preamble: "Reviewed N open Dependabot PRs in <repo>."
2. A **summary table** (see the "Audit summary table" section below for the shape).
3. A **Details** section with one subsection per PR, each following the single-PR output format (but condensed — keep per-PR detail to ~15-25 lines).
4. A closing **Overall recommendation** block: which PRs to merge now, which to investigate, which to hold. Group by verdict so the dev can work top-to-bottom.

### Step A4: Offer to post findings as PR comments

After the consolidated report, follow the shared **"Posting findings to PRs"** section below. For audit mode, the opt-in prompt covers the whole batch ("yes / no / selective"), and the comment body for each PR is drawn from that PR's per-PR detail section in Step A3.

### Audit summary table

The summary table is the first thing the dev reads — its job is to let them triage the whole batch in under a minute. Render it as a GitHub-flavored markdown table with these exact columns, in this order:

| Column     | Contents                                                              |
|------------|-----------------------------------------------------------------------|
| `#`        | PR number, linked as `[#9170](url)`                                   |
| `Gem`      | Gem name. For multi-gem PRs, comma-separate (e.g., `rspec-core, rspec-expectations`) |
| `Bump`     | `old → new` (e.g., `7.2.4 → 8.0.10`)                                  |
| `Type`     | `patch`, `minor`, or `major`. Prefix with `🔒` if the PR addresses a security advisory |
| `Age`      | Days since `createdAt` (e.g., `3d`, `21d`)                            |
| `Verdict`  | Abbreviated: `Merge`, `Verify`, `Investigate`, `Hold`                 |
| `Why`      | One short clause (≤ 10 words). Concrete, not generic — e.g., "dev-only, no breaking changes" beats "looks safe" |

**Sort order:** primary key is verdict in the order `Merge → Verify → Investigate → Hold` (worklist-style — easy wins first, stop when you hit "Investigate"). Within each verdict bucket, sort by `Age` descending so the stalest PRs rise to the top of their bucket — PRs that have been rotting in the queue often hide the real merge friction.

**Security exception:** any row with the 🔒 marker jumps to the top of the entire table regardless of verdict bucket, because security urgency overrides the triage-by-ease ordering.

**Verdict abbreviations** (use these exact strings so the column stays narrow and scannable):
- `Merge` — safe, low risk
- `Verify` — safe pending specific checks (detail lives in the per-PR section)
- `Investigate` — needs human judgment
- `Hold` — breaking changes require code work first

Do not add extra columns (branch name, author, CI status, labels). Seven is already the comfortable ceiling for terminal width, and every extra column dilutes the signal. If something doesn't fit the table, it belongs in the per-PR detail section, not here.

## Single-PR workflow

### Step 1: Fetch PR Details

Parse the PR URL to extract the owner, repo, and PR number. When invoked via audit mode, these come from the `gh pr list` output — no parsing needed.

```bash
gh pr view <NUMBER> --repo <OWNER/REPO> --json title,body,url,files,headRefName
gh pr diff <NUMBER> --repo <OWNER/REPO>
```

From the diff, extract for each gem being updated:
- **Gem name**, **old version**, **new version**
- **Bump type**: patch (0.0.x), minor (0.x.0), or major (x.0.0)

If the PR updates multiple gems, analyze them together in a combined summary with one section per gem.

### Step 2: Review Changelog & Breaking Changes

This is the most important step. Developers need to know what changed and whether anything will break.

Fetch the changelog between old and new versions. Try these sources:

1. **GitHub changelog** — use `gh` to fetch the raw changelog file from the gem's repo (usually `CHANGELOG.md`, `Changes.md`, or `HISTORY.md` at the repo root)
2. **GitHub releases** — check `https://github.com/<gem-source-repo>/releases`
3. **RubyGems.org** — `https://rubygems.org/gems/<gem-name>` links to the source

**Patch/minor bumps:** read the relevant version sections in full — they're short.

**Major bumps:** do not read the full changelog or migration guide. Large gems (Rails, Sidekiq, Devise, ActiveRecord) have thousands of lines of changelog prose that will exhaust context before you reach the codebase-impact step. Instead:
1. Fetch the raw changelog file and use `grep` to extract only sections matching the version range (e.g., `grep -n "^## \[" CHANGELOG.md` to find section line numbers, then read only that range).
2. Within the extracted range, focus on lines or subsections containing "breaking", "removed", "renamed", "dropped", "changed default", or "incompatible". Skip narrative paragraphs and new-feature prose.
3. Cross-reference with GitHub Releases for the major version tag — release notes often summarise breaking changes more concisely than the full changelog.

The goal is a targeted list of breaking changes and deprecations, not a comprehensive retelling of everything that changed.

Organize findings by importance:

1. **Breaking changes** — removed/renamed APIs, changed defaults, dropped Ruby/Rails version support. For each breaking change, check whether the codebase is affected and suggest a concrete fix if so.
2. **Deprecations** — still works now, will break later. Note what to watch for.
3. **Security fixes** — increases urgency to merge.
4. **Notable bug fixes and new features** — only mention if relevant to the codebase.

If you cannot find a changelog, say so explicitly.

### Step 3: Find Codebase Impact

Search the codebase to understand what this gem touches and what's at stake if it breaks.

1. **Gemfile entry** — check version constraints and which group (`:development`, `:test`, or production).
2. **Search for usage** — find the gem's module/class names in `app/`, `lib/`, `config/`, and `spec/`. Check `config/initializers/` for configuration.
3. **Map to features** — group files by feature area (payments, notifications, order processing, etc.) and describe what each area does in plain language.
4. **Ecosystem gems** — check if other gems depend on this one (e.g., `sentry-sidekiq` depends on `sidekiq`). Verify their version constraints are compatible by checking the Gemfile.lock diff — if Bundler resolved successfully, note that.

For dev/test-only gems, note the lower risk profile (broken dev workflow vs broken customer experience).

Keep this section concise: a grouped list of affected areas, not an exhaustive file listing.

### Step 4: Recommendation

Deliver a clear, concise verdict. Consider:

| Factor | Lower Risk | Higher Risk |
|--------|-----------|-------------|
| Bump type | Patch | Major |
| Usage scope | 1-2 files, dev/test only | Widespread, production |
| Feature area | Admin, dev tooling | Payments, auth, orders |
| Changelog | No breaking changes | API changes, deprecations |
| Security fix | No | Yes (merge sooner) |

Verdicts:
- **Merge** — safe, low risk
- **Merge after verification** — looks safe but has specific things to verify first (list them)
- **Investigate** — specific concerns that need human judgment (list them)
- **Hold** — breaking changes or compatibility issues that need code changes before merging

Do not recommend running the test suite — CI handles that. Instead, call out specific things a human should verify that tests might not catch (e.g., production Redis version, runtime behavior changes, new deprecation warnings in logs).

### Step 5: Offer to post the review as a PR comment

After presenting the review in chat, follow the shared **"Posting findings to PRs"** section below. In single-PR mode the prompt is a simple yes/no ("Want me to post this review as a comment on the PR?"), and the comment body is drawn from the review you just produced.

## Output Format

The output should be concise and scannable. Use this structure:

```
## Dependabot Review: `gem_name` (old_version -> new_version)

### Bump Type
[patch/minor/major] — [one line: what this means for risk]

### What Changed
[Changelog highlights organized by importance: breaking changes first (with fix suggestions), then deprecations, security fixes, and notable changes. Skip noise. If nothing notable, say "No breaking changes or deprecations."]

### Breaking Changes in This Codebase
[Only if there ARE breaking changes: list each one with the affected file and a concrete fix suggestion. If no breaking changes affect the codebase, omit this section entirely.]

### Codebase Impact
[Concise grouped list of what this gem touches: "Payments: captures charges via checkoutcom jobs", "Notifications: 12 push/email notification jobs", etc. One line per area.]

### Recommendation
[Verdict + 1-3 sentences explaining why and what to verify]
```

For multi-gem PRs, use one top-level heading and a section per gem, then a single combined recommendation at the end.

In **audit mode**, each per-PR subsection uses the same structure but condensed (aim for 15-25 lines). The top-level summary table and Overall recommendation (defined in the audit workflow) replace the single-PR verdict block.

## Posting findings to PRs

This section applies to **both** single-PR mode (Step 5) and audit mode (Step A4). Always run it — producing a review without offering to post it back to the PR means the work lives only in the chat transcript, which isn't where a team actually reviews code.

### Opt-in prompt

Posting is a visible, public-facing action, so always ask before posting — never post automatically. Ask once, and keep the prompt short:

- **Single-PR mode:** "Want me to post this review as a comment on PR #<number>? (yes / no)"
- **Audit mode:** "Want me to post each PR's review as a comment on its PR? (yes / no / selective)"
  - **yes** → post to every PR analyzed
  - **no** → stop; the report in chat is the only output
  - **selective** → ask which PR numbers to post on, then post to just those

If the user answers "no", stop there. If "yes" or "selective", proceed to the idempotency check and then posting.

### Command

```bash
gh pr comment <NUMBER> --repo <OWNER/REPO> --body-file <path-to-tempfile>
```

Use `--body-file` rather than `--body` so newlines, backticks, and markdown tables survive the shell without escaping headaches. Write each comment to a temp file first (e.g., `/tmp/dep-review-<pr-number>.md`), then pass the path.

### Comment template

Use this exact structure per PR:

```markdown
## Dependabot review

**Verdict:** <Merge / Verify / Investigate / Hold>

<one-line reason — the core of why this verdict>

<details>
<summary>Full review</summary>

<the full review output: Bump Type, What Changed, Breaking Changes in This Codebase (if any), Codebase Impact, Recommendation>

</details>

<!-- dependabot-audit:v1 -->
```

Rationale for each element:
- The verdict and one-liner sit above the fold so a teammate scrolling the PR timeline can triage without expanding.
- The `<details>` block keeps the long analysis collapsed — PR comments that dump 40 lines of unrequested content are noisy and get ignored.
- The trailing `<!-- dependabot-audit:v1 -->` HTML comment is invisible in the rendered view but lets a future run detect its own prior comment and decide whether to skip or update instead of duplicating.
- **Do not** add any signature, "posted by", "generated by", or attribution line. The comment should read as if written by the user who posted it.

### Idempotency check

Before posting to any PR, run:

```bash
gh api repos/<OWNER>/<REPO>/issues/<NUMBER>/comments --paginate \
  --jq '.[].body' | grep -q 'dependabot-audit:v1'
```

If the marker is found, a prior review comment already exists. Mention it in the confirmation prompt ("PR #9170 already has a prior review comment — re-post anyway?") so the user can choose to skip, replace (delete the old comment via `gh api --method DELETE /repos/<owner>/<repo>/issues/comments/<id>` and post new), or leave it alone. Default to skipping if the user doesn't specify.

### Failure handling

If `gh pr comment` fails for one PR (permissions, locked PR, rate limit), report the failure inline and continue. In audit mode, do not abort the whole batch because one comment failed.

### Confirmation output

After posting, show a short line:
- Single-PR: "Posted comment on #<number>."
- Audit: "Posted N comments: [#9170, #9157, …]. Skipped M: [#9064 (had prior review)]."
