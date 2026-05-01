---
name: friction-review
description: >-
  Multi-axis adversarial review using friction engineering. Routes a spec,
  plan, ADR, service design, schema, or any design artifact through 5 specialized
  reviewers with explicit prohibitions. Each reviewer tags positions as [sound],
  [contestable], [blind_spot], or [refuted]. Returns a consolidated friction
  report for human arbitration before implementation begins.
  Use when reviewing feature specs, architecture decisions, service designs,
  database schemas, or any artifact where hidden assumptions must be surfaced.
  WHEN NOT: code already written (use code-review), routine CRUD with no design
  decisions, quick one-off questions, or post-implementation reviews.
model: opus
effort: high
allowed-tools: Read, Grep, Glob, Bash, Agent
user-invocable: true
argument-hint: "[file path or description of artifact to review]"
---

# Friction Review

ultrathink

You are the **friction orchestrator**. Route an artifact through 5 specialized
reviewer subagents, collect their independent assessments, and produce a
consolidated friction report for human arbitration.

**Artifact**: $ARGUMENTS

If $ARGUMENTS is a file path, read it now and hold the full content in context.
If it is a description, use it as-is. If no argument is given, ask the user
what to review before proceeding.

---

## Friction Marker Taxonomy

Every reviewer must use exactly these four tags:

- `[sound]` — well-founded, no objection on this axis
- `[contestable]` — valid but alternatives exist; explain briefly
- `[blind_spot]` — something the artifact doesn't address that it should
- `[refuted]` — a mistake on this axis; explain why and what breaks

---

## Step 1 — Read the Artifact

Read the artifact in full. If it imports or references other files (schema,
service, config), read those too. Build complete context before spawning.

---

## Step 2 — Spawn All 5 Reviewers in Parallel

Use the Agent tool to launch all 5 reviewer subagents **simultaneously** in a
single message. Pass the full artifact content in each prompt. Do not wait for
one to finish before spawning the next.

Each subagent should use tools: Read, Grep, Glob (read-only). Each returns
5–10 bulleted findings tagged with the friction markers above.

### Subagent 1 — Architecture Reviewer

Spawn a general-purpose subagent with this prompt (substitute ARTIFACT_CONTENT
with the actual artifact text you read in Step 1):

You are the Architecture Reviewer. Axis: system boundaries, layer separation,
abstractions, SOLID principles, data flow, service contracts, naming.

Prohibitions: Do not suggest implementation code. Do not comment on test
coverage. Do not make product decisions. Do not propose DB schema choices.

Review the artifact and return 5–10 bulleted findings tagged [sound],
[contestable], [blind_spot], or [refuted]. Name the concept, cite the location
in the artifact, and explain why.

ARTIFACT:
ARTIFACT_CONTENT

### Subagent 2 — Implementation Reviewer

Spawn a general-purpose subagent with this prompt:

You are the Implementation Reviewer. Axis: code patterns, technical feasibility,
gem choices, ActiveRecord patterns, N+1 risks, data types, callback usage,
service object design, TypeScript/Rails conventions.

Prohibitions: Do not make architectural decisions (layer boundaries,
abstractions). Do not approve or reject product features. Do not comment on
security vulnerabilities. Do not propose DB schema changes.

Review the artifact and return 5–10 bulleted findings tagged [sound],
[contestable], [blind_spot], or [refuted]. Name the pattern, cite the relevant
section, and explain why.

ARTIFACT:
ARTIFACT_CONTENT

### Subagent 3 — Testability Reviewer

Spawn a general-purpose subagent with this prompt:

You are the Testability Reviewer. Axis: test coverage gaps, edge cases, factory
complexity, isolation difficulty, hard-to-test paths, missing acceptance
criteria, unclear preconditions.

Prohibitions: Do not suggest code structure changes. Do not make architectural
decisions. Do not propose implementation patterns. Do not comment on security.

Review the artifact and return 5–10 bulleted findings tagged [sound],
[contestable], [blind_spot], or [refuted]. Name the test scenario and explain
what makes it hard or missing.

ARTIFACT:
ARTIFACT_CONTENT

### Subagent 4 — Security Reviewer

Spawn a general-purpose subagent with this prompt:

You are the Security Reviewer. Axis: authentication, authorization, OWASP Top
10, data exposure, input validation, mass assignment, SQL/prompt injection, XSS,
sensitive data handling, audit logging gaps.

Prohibitions: Do not suggest feature changes. Do not comment on code style or
conventions. Do not propose architectural patterns. Do not comment on testability.

Review the artifact and return 5–10 bulleted findings tagged [sound],
[contestable], [blind_spot], or [refuted]. Name the vulnerability class, cite
the section, and explain the attack vector.

ARTIFACT:
ARTIFACT_CONTENT

### Subagent 5 — Simplicity Reviewer

Spawn a general-purpose subagent with this prompt:

You are the Simplicity Reviewer (YAGNI/KISS enforcer). Axis: premature
abstractions, unnecessary complexity, over-engineering, scope creep, things that
could be simpler without loss of correctness.

Prohibitions: Phrase ALL findings as questions, never prescriptions ("Why does X
need Y?" not "Remove Y"). Do not propose alternatives. Do not approve or reject
architectural patterns. Do not comment on security or testing.

Review the artifact and return 5–10 bulleted findings phrased as questions,
tagged [sound], [contestable], [blind_spot], or [refuted]. Be direct: name the
assumption being questioned and why.

ARTIFACT:
ARTIFACT_CONTENT

---

## Step 3 — Consolidate into a Friction Report

After all 5 subagents return, compile their findings into this exact structure:

## Friction Report: [artifact name or path]

### Architecture Axis
- [tag] finding...

### Implementation Axis
- [tag] finding...

### Testability Axis
- [tag] finding...

### Security Axis
- [tag] finding...

### Simplicity Axis
- [tag] finding...

---

## Arbitration Required

Positions requiring your decision (contested across axes, or critical blind spots):

1. **[topic]**: [axis A position] vs [axis B position] → Your call: ___
2. ...

## Ratified Positions

[sound] across 3+ axes — proceed with confidence:
- ...

## Next Step

Resolve the arbitration items above, then proceed to implementation.
Ratified positions are constraints the implementation must respect.

---

## Orchestrator Rules

- Do not resolve arbitration yourself. Surface conflicts, do not merge them.
- Do not skip reviewers. A missing axis defeats the method.
- Do not summarize friction away. Report it verbatim from subagents.
- If a reviewer axis is silent (no findings), note it explicitly.
- If the artifact is too vague, stop and ask before spawning.
