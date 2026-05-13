# GitHub Copilot Instructions

Use these instructions as a compatibility bridge so GitHub Copilot can reuse this repo's Claude-oriented assets without duplicating them.

## Canonical Sources

- Architecture and workflow conventions: `AGENTS.md`
- Canonical Claude instructions and rules: `.claude/`
- Copilot-friendly mirrored skills: `.agents/skills/`

## Rule Loading Strategy

- Path-scoped Copilot bridge files live in `.github/instructions/claude-rules/`.
- Each bridge points to a canonical `.claude/rules/*.md` file.
- Follow the canonical `.claude/rules/*.md` content, not the bridge text.

## Skills Strategy

- Treat `.agents/skills/*/SKILL.md` as Copilot-facing skills.
- `.claude/skills/` remains the source of truth.

## Maintenance Rules

- Do not rewrite or duplicate `.claude/rules/*` content into `.github/instructions/*`.
- Do not manually copy `.claude/skills/*` into `.agents/skills/*`.
- Keep bridges and mirrors in sync via scripts:

```bash
scripts/sync_claude_rules_to_copilot.sh
scripts/sync_claude_skills_to_codex.sh
```

Run both scripts after adding, removing, or renaming a rule or skill.
