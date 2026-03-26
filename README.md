# Rails AI Agents

A production-ready Claude Code setup for Ruby on Rails development: **18 specialized agents**, **17 skills**, **10 path-scoped rules**, and **5 lifecycle hooks**. Drop it into your project and your AI assistant instantly knows Rails conventions, TDD workflows, and production patterns.

Also includes:
- separate [37signals-style collection](#37signals-collection).
- Claude Code Extensibility Guide
- AI Terminology Glossary — 289 terms across 25 categories. Also available as a [browsable HTML version](https://thibautbaissac.github.io/ai/glossary.html).


## Quick Start

```bash
# Copy the .claude/ directory into your Rails project
cp -r .claude/ /path/to/your-rails-app/.claude/
```

Agents and skills auto-activate based on what you ask. Say "create a service object for order processing" and the `service-agent` takes over. Say "write tests for this model" and `rspec-agent` kicks in.

You can also invoke skills directly:

```
/feature-spec user registration
/code-review
/security-audit
/tdd-cycle
```

## What's Inside

### Agents (`.claude/agents/`)

18 specialist agents, each with `permissionMode: acceptEdits`, `memory: project`, `maxTurns` limits, and WHEN/WHEN NOT descriptions for auto-delegation.

| Agent | Domain | Model |
|---|---|---|
| `model-agent` | ActiveRecord models, validations, associations, scopes | sonnet |
| `controller-agent` | Thin RESTful controllers, strong params, Pundit | sonnet |
| `service-agent` | Service objects, Result pattern, SOLID | sonnet |
| `migration-agent` | Safe, reversible database migrations | sonnet |
| `policy-agent` | Pundit authorization policies | sonnet |
| `form-agent` | Multi-model forms, wizard forms | sonnet |
| `query-agent` | Complex queries, N+1 prevention | sonnet |
| `presenter-agent` | View logic separation with SimpleDelegator | sonnet |
| `viewcomponent-agent` | Reusable, tested UI components | sonnet |
| `job-agent` | Background jobs with Solid Queue | sonnet |
| `mailer-agent` | ActionMailer with previews and templates | sonnet |
| `turbo-agent` | Turbo Frames, Streams, Drive | sonnet |
| `stimulus-agent` | Stimulus controllers | sonnet |
| `tailwind-agent` | Tailwind CSS styling | sonnet |
| `rspec-agent` | RSpec tests (preloads `tdd-cycle` skill) | sonnet |
| `implementation-agent` | TDD GREEN phase orchestrator (worktree isolation) | sonnet |
| `tdd-refactoring-agent` | TDD REFACTOR phase (preloads `tdd-cycle` skill) | sonnet |
| `lint-agent` | RuboCop linting and auto-correction | haiku |

### Skills (`.claude/skills/`)

17 skills with reference docs. Two patterns: **task skills** (user-invocable workflows) and **knowledge skills** (auto-loaded conventions).

| Skill | Type | Purpose |
|---|---|---|
| `feature-spec` | Task | Structured interview to write a complete spec with Gherkin scenarios |
| `feature-review` | Task | Scores specs 0-10, identifies gaps, generates missing scenarios |
| `feature-plan` | Task | Converts spec into TDD implementation plan with PR breakdown |
| `code-review` | Task | SOLID analysis, N+1 detection, anti-patterns (read-only) |
| `security-audit` | Task | OWASP Top 10 audit with Brakeman (runs with opus) |
| `tdd-cycle` | Task | Guides full Red-Green-Refactor cycle |
| `frame-problem` | Task | Reframes vague requests into clear problems |
| `rails-architecture` | Knowledge | Layered architecture decisions (runs with opus) |
| `authentication-flow` | Knowledge | Rails 8 built-in authentication |
| `caching-strategies` | Knowledge | Fragment, Russian doll, low-level caching |
| `performance-optimization` | Knowledge | N+1 detection, query optimization |
| `action-cable-patterns` | Knowledge | WebSocket real-time features |
| `active-storage-setup` | Knowledge | File uploads and variants |
| `api-versioning` | Knowledge | RESTful API design |
| `i18n-patterns` | Knowledge | Internationalization |
| `solid-queue-setup` | Knowledge | Background job configuration |
| `rails-concern` | Knowledge | Shared behavior with concerns |

### Rules (`.claude/rules/`)

10 path-scoped rules that auto-load only when Claude works on matching files:

| Rule | Scoped to |
|---|---|
| `models.md` | `app/models/**`, `spec/models/**`, `spec/factories/**` |
| `controllers.md` | `app/controllers/**`, `spec/requests/**` |
| `services.md` | `app/services/**`, `spec/services/**` |
| `queries.md` | `app/queries/**`, `spec/queries/**` |
| `policies.md` | `app/policies/**`, `spec/policies/**` |
| `jobs.md` | `app/jobs/**`, `spec/jobs/**` |
| `mailers.md` | `app/mailers/**`, `spec/mailers/**` |
| `migrations.md` | `db/migrate/**`, `db/schema.rb` |
| `views.md` | `app/views/**`, `app/components/**`, `app/presenters/**` |
| `testing.md` | `spec/**` |

### Hooks (`.claude/settings.json`)

| Hook | Event | What it does |
|---|---|---|
| **SessionStart** | Session begins | Injects project context (branch, Ruby/Rails version, pending migrations) |
| **PostToolUse** | After Edit/Write | Auto-formats Ruby files with RuboCop |
| **PreToolUse** | Before Bash | Blocks destructive commands (rm -rf, DROP TABLE, force push to main) |
| **TaskCompleted** | Task marked done | Quality gate: reminds to run tests and linting |
| **Stop** | Response ends | Desktop notification |

### Settings

- **Agent Teams** enabled (`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS`)
- **JSON Schema** for editor autocomplete
- **Smart model routing**: opus for architecture/security, sonnet for coding, haiku for linting

## Typical Workflow

```
/feature-spec checkout flow        # 1. Write the spec
/feature-review features/checkout  # 2. Review and score it
/feature-plan features/checkout    # 3. Break into PRs

# TDD cycle (agents auto-delegate)
@rspec-agent write failing tests   # 4. RED
@implementation-agent              # 5. GREEN (runs in worktree)
@tdd-refactoring-agent             # 6. REFACTOR

/code-review                       # 7. Quality check
/security-audit                    # 8. Security check
```

## Project Structure

```
.claude/
  settings.json              # Hooks, env, Agent Teams
  settings.local.json        # Local permissions (gitignored)
  agents/                    # 18 specialist agents
    model-agent.md
    service-agent.md
    ...
    references/              # Agent reference docs (patterns, testing)
      model/
      service/
      ...
  skills/                    # 17 skills
    feature-spec/SKILL.md
    rails-architecture/SKILL.md
    ...
  rules/                     # 10 path-scoped rules
    models.md
    controllers.md
    ...
37signals_skills/            # 18 skills, 37signals/Basecamp style
claude-code-extensibility-guide.md  # Comprehensive extensibility reference
glossary.md                  # AI terminology glossary
```

## Extensibility Guide

The [Claude Code Extensibility Guide](claude-code-extensibility-guide.md) covers all extension mechanisms: CLAUDE.md, skills, hooks, subagents, Agent Teams, MCP servers, and plugins. Includes decision trees, configuration references, community patterns, and an adoption playbook.

## License

MIT
