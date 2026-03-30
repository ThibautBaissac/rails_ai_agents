# Rails AI Agents

A production-ready Claude Code setup for Ruby on Rails development: **18 specialized agents**, **19 slash commands** (including the [SDD kit](#spec-driven-development-sdd-kit)), **13 skills**, **12 path-scoped rules**, and **6 lifecycle hooks**. Drop it into your project and your AI assistant instantly knows Rails conventions, TDD workflows, and production patterns.

Also includes:
- [Spec Driven Development (SDD) kit](#spec-driven-development-sdd-kit) — a full specification-to-implementation pipeline + [lightweight mode](#sdd-change-lightweight-mode) for bug fixes.
- separate [37signals-style collection](#37signals-collection).
- Claude Code Extensibility Guide
- AI Terminology Glossary — 289 terms across 25 categories. Also available as a [browsable HTML version](https://thibautbaissac.github.io/ai/glossary.html).


## Quick Start

```bash
# Copy the .claude/ directory into your Rails project
cp -r .claude/ /path/to/your-rails-app/.claude/
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

### Commands (`.claude/commands/`)

6 standalone slash commands for feature development workflows. See also [SDD commands](#sdd-commands-claudecommandssdd) below.

| Command | Purpose |
|---|---|
| `/feature-spec` | Structured interview to write a complete spec with Gherkin scenarios |
| `/feature-spec-review` | Scores specs, identifies gaps, generates missing scenarios |
| `/feature-plan` | Converts spec into TDD implementation plan with PR breakdown |
| `/feature-tdd-implementation` | Guides full Red-Green-Refactor TDD workflow |
| `/frame-problem` | Reframes vague requests into clear problems |
| `/prompt-improver` | Scores and rewrites vague prompts into specific, actionable ones |

### Skills (`.claude/skills/`)

13 skills with reference docs. Two patterns: **task skills** (user-invocable workflows) and **knowledge skills** (auto-loaded conventions).

| Skill | Type | Purpose |
|---|---|---|
| `code-review` | Task | SOLID analysis, N+1 detection, anti-patterns (read-only) |
| `security-audit` | Task | OWASP Top 10 audit with Brakeman (runs with opus) |
| `rails-architecture` | Knowledge | Layered architecture decisions (runs with opus) |
| `authentication-flow` | Knowledge | Rails 8 built-in authentication |
| `caching-strategies` | Knowledge | Fragment, Russian doll, low-level caching |
| `performance-optimization` | Knowledge | N+1 detection, query optimization |
| `extraction-timing` | Knowledge | When and how to extract services, queries, concerns |
| `action-cable-patterns` | Knowledge | WebSocket real-time features |
| `active-storage-setup` | Knowledge | File uploads and variants |
| `api-versioning` | Knowledge | RESTful API design |
| `i18n-patterns` | Knowledge | Internationalization |
| `solid-queue-setup` | Knowledge | Background job configuration |
| `rails-concern` | Knowledge | Shared behavior with concerns |

### Rules (`.claude/rules/`)

12 path-scoped rules that auto-load only when Claude works on matching files:

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
| `principles.md` | `app/**/*.rb` |
| `anti-patterns.md` | `app/**/*.rb`, `spec/**/*.rb` |

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

## Spec Driven Development (SDD) Kit

A structured specification-to-implementation pipeline powered by 10 slash commands. SDD enforces a disciplined workflow: define what you're building before writing code, validate requirements quality, then implement from a task plan.

### SDD Commands (`.claude/commands/sdd/`)

| Command | Purpose |
|---|---|
| `/sdd:constitution` | Create or update the project constitution — core principles and governance rules |
| `/sdd:specify` | Generate a feature specification from a natural language description |
| `/sdd:clarify` | Ask up to 5 targeted questions to reduce ambiguity in the spec |
| `/sdd:spec-review` | Adversarial review of the spec from security, performance, edge-case, scalability, and compliance perspectives |
| `/sdd:checklist` | Generate a requirements quality checklist |
| `/sdd:plan` | Create a technical implementation plan with research, data model, and contracts |
| `/sdd:tasks` | Break the plan into dependency-ordered, executable tasks organized by user story |
| `/sdd:analyze` | Read-only consistency analysis across spec, plan, and tasks |
| `/sdd:implement` | Execute the task plan phase-by-phase with progress tracking |
| `/sdd:implement-subagents` | Same as implement, but spawns a fresh-context subagent per task to prevent context rot on large features |

### SDD Workflow

```
/sdd:constitution                  # 1. Define project principles (once)
/sdd:specify user authentication   # 2. Write the feature spec
/sdd:clarify                       # 3. Resolve ambiguities (optional)
/sdd:spec-review                   # 4. Adversarial review from 5 perspectives (optional)
/sdd:checklist security            # 5. Validate requirements quality (optional)
/sdd:plan                          # 6. Generate technical plan + data model
/sdd:tasks                         # 7. Break into ordered tasks
/sdd:analyze                       # 8. Cross-artifact consistency check
/sdd:implement                     # 9. Execute tasks with verification
# Or for large features:
/sdd:implement-subagents           # 9. Fresh-context subagent per task (prevents context rot)
```

Each command hands off to the next via suggested prompts. The pipeline creates a `specs/<branch-name>/` directory with all artifacts:

```
specs/001-user-auth/
├── spec.md           # Feature specification (/sdd:specify)
├── plan.md           # Implementation plan (/sdd:plan)
├── research.md       # Technical research & decisions (/sdd:plan)
├── data-model.md     # Entity definitions (/sdd:plan)
├── quickstart.md     # Integration scenarios (/sdd:plan)
├── contracts/        # Route and API contracts (/sdd:plan)
├── tasks.md          # Executable task list (/sdd:tasks)
└── checklists/       # Requirements quality checklists (/sdd:checklist)
```

### SDD Infrastructure (`.specify/`)

The `.specify/` directory contains the scaffolding that powers SDD commands:

- **`templates/`** — Markdown templates for specs, plans, tasks, checklists, constitutions, and agent context files
- **`scripts/bash/`** — Shell scripts for branch creation, prerequisite checking, plan setup, and agent context updates
- **`memory/`** — Persistent project state (constitution, lessons learned across features)
- **`init-options.json`** — Configuration (branch numbering mode, AI agent type)

SDD supports extensibility via `.specify/extensions.yml` for before/after hooks on any command, template overrides in `.specify/templates/overrides/`, and presets in `.specify/presets/`.

### Key SDD Concepts

- **Constitution** — Non-negotiable project principles validated at every planning gate
- **Lessons Learned** — Cross-feature learnings accumulate in `.specify/memory/lessons-learned.md` and feed into future planning and implementation
- **Adversarial Spec Review** — `/sdd:spec-review` challenges the spec from security, performance, edge-case, scalability, and compliance perspectives before planning begins
- **Specs are stakeholder-facing** — No implementation details; focus on WHAT and WHY
- **Checklists are "unit tests for English"** — They validate requirements quality, not implementation correctness
- **Tasks organized by user story** — Each story is independently implementable and testable (MVP-first)
- **Fresh-context implementation** — `/sdd:implement-subagents` spawns a clean subagent per task, preventing context rot on large features

### SDD Small-Change (Lightweight Mode)

For bug fixes and small features that don't need the full SDD ceremony. Three commands, no plan, no checklists, no analysis — just specify, task, implement.

#### Commands (`.claude/commands/sdd-change/`)

| Command | Purpose |
|---|---|
| `/sdd-change:specify` | Create a minimal change spec (problem, fix, acceptance criteria, files affected) |
| `/sdd-change:tasks` | Generate a flat 3-8 task list from the change spec |
| `/sdd-change:implement` | Execute tasks sequentially with validation |

#### Workflow

```
/sdd-change:specify Fix login timeout — sessions expire after 5min instead of 30
/sdd-change:tasks
/sdd-change:implement
```

#### When to Use Which

| Situation | Use |
|---|---|
| Bug fix, patch, tweak | `/sdd-change:specify` |
| New feature, multi-story epic | `/sdd:specify` |
| Refactor touching 1-3 files | `/sdd-change:specify` |
| Refactor touching 6+ files | `/sdd:specify` |

The lightweight pipeline warns you if your change looks too complex (>3 acceptance criteria or >6 files affected) and suggests switching to the full pipeline.

## Extensibility Guide

The [Claude Code Extensibility Guide](docs/claude-code-extensibility-guide.md) covers all extension mechanisms: CLAUDE.md, skills, hooks, subagents, Agent Teams, MCP servers, and plugins. Includes decision trees, configuration references, community patterns, and an adoption playbook.

## License

MIT
