# Rails AI Skills

A library of 48 AI skills for Ruby on Rails development. Drop them into your project and your AI coding assistant instantly knows Rails conventions, TDD workflows, and production patterns.

Works with Mistral Vibe, Claude Code, GitHub Copilot, Cursor, Gemini CLI, and [30+ other tools](https://agentskills.io/specification) that support the Agent Skills standard.

Also includes a separate [37signals-style collection](#37signals-collection) (18 skills) for teams following the Basecamp approach.

> For original agents and skills, see [this commit](https://github.com/ThibautBaissac/rails_ai_agents/tree/15fdeaf68af5d7ef274277217af27fe5a5f07e45).

## Quick Start

```bash
# Copy the skills into your Rails project
cp -r .agents/ /path/to/your-rails-app/.agents/

# For Claude Code, also copy the symlinked discovery directory
cp -rP .claude/skills/ /path/to/your-rails-app/.claude/skills/
```

Skills auto-activate based on what you ask. Say "create a service object for order processing" and the `rails-service-object` skill kicks in. Say "write tests for this model" and `rspec-agent` takes over.

You can also invoke them directly:

```
/feature-spec user registration
/code-review
/security-audit
/tdd-red-agent
```

## What's Inside

### Feature Specification Workflow

Three skills that take you from idea to implementation plan:

| Skill | Purpose |
|---|---|
| `feature-spec` | Structured interview to write a complete spec with Gherkin scenarios |
| `feature-review` | Scores the spec 0-10, identifies gaps, generates missing scenarios |
| `feature-plan` | Converts spec into a TDD implementation plan with PR breakdown |

### TDD Workflow

| Skill | Phase | What it does |
|---|---|---|
| `tdd-cycle` | All | Guides the full Red-Green-Refactor cycle |
| `tdd-red-agent` | Red | Writes failing tests. Never touches `app/` |
| `implementation-agent` | Green | Coordinates specialist agents to make tests pass |
| `tdd-refactoring-agent` | Refactor | Improves code while keeping tests green |
| `rspec-agent` | Any | Writes comprehensive specs for existing code |

### Rails Layer Specialists

Isolated agents (`context: fork`) with deep domain knowledge:

| Skill | Domain |
|---|---|
| `model-agent` | ActiveRecord models, validations, associations, scopes |
| `controller-agent` | Thin RESTful controllers, strong params, Pundit |
| `service-agent` | Service objects, Result pattern, SOLID |
| `migration-agent` | Safe, reversible database migrations |
| `policy-agent` | Pundit authorization policies |
| `form-agent` | Multi-model forms, wizard forms |
| `query-agent` | Complex queries, N+1 prevention |
| `presenter-agent` | View logic separation with SimpleDelegator |
| `viewcomponent-agent` | Reusable, tested UI components |
| `job-agent` | Background jobs with Solid Queue |
| `mailer-agent` | ActionMailer with previews and templates |
| `turbo-agent` | Turbo Frames, Streams, Drive |
| `stimulus-agent` | Stimulus controllers |
| `tailwind-agent` | Tailwind CSS styling |
| `lint-agent` | RuboCop linting and auto-correction |

### Pattern & Knowledge Skills

Injected inline (no subprocess) — they teach conventions:

| Skill | Teaches |
|---|---|
| `rails-architecture` | Layered architecture, where to put code |
| `rails-service-object` | Service object pattern with Result class |
| `rails-model-generator` | Model generation with TDD |
| `rails-controller` | Controller conventions with request specs |
| `rails-concern` | Shared behavior with concerns |
| `rails-presenter` | Presenter/decorator pattern |
| `rails-query-object` | Query object pattern |
| `authentication-flow` | Rails 8 built-in authentication |
| `authorization-pundit` | Policy-based authorization |
| `hotwire-patterns` | Turbo + Stimulus patterns |
| `viewcomponent-patterns` | ViewComponent patterns |
| `form-object-patterns` | Form object patterns |
| `database-migrations` | Migration best practices |
| `caching-strategies` | Fragment, Russian doll, low-level caching |
| `performance-optimization` | N+1 detection, query optimization |
| `action-cable-patterns` | WebSocket real-time features |
| `action-mailer-patterns` | Transactional emails |
| `active-storage-setup` | File uploads and variants |
| `api-versioning` | RESTful API design |
| `i18n-patterns` | Internationalization |
| `solid-queue-setup` | Background job configuration |

### Utilities

| Skill | Purpose |
|---|---|
| `code-review` | SOLID analysis, N+1 detection, anti-patterns (read-only) |
| `security-audit` | OWASP Top 10 audit with Brakeman |
| `frame-problem` | Reframes vague requests into clear problems |
| `refine-specification` | Clarifying questions for draft specs |

## Typical Workflow

```
/feature-spec checkout flow        # 1. Write the spec
/feature-review features/checkout  # 2. Review and score it
/feature-plan features/checkout    # 3. Break into PRs

/tdd-red-agent                     # 4. Write failing tests (RED)
/implementation-agent              # 5. Make them pass (GREEN)
/tdd-refactoring-agent             # 6. Clean up (REFACTOR)

/code-review                       # 7. Quality check
/security-audit                    # 8. Security check
```

## 37signals Collection

The `37signals_skills/` directory contains 18 skills following the Basecamp/HEY philosophy. Key differences from the main collection:

| | Main collection | 37signals |
|---|---|---|
| Business logic | Service objects | Fat models |
| Tests | RSpec + FactoryBot | Minitest + fixtures |
| Shared behavior | Separate layers | Concerns everywhere |
| Request context | Explicit params | `Current` attributes |
| State | Enums / booleans | State as records |
| IDs | Integer (default) | UUIDs |
| Multi-tenancy | Various | URL-based with `Current.account` |

To use them, copy `37signals_skills/` into your project's `.agents/skills/` directory.

## How Skills Work

Each skill is a folder with a `SKILL.md` file:

```
skill-name/
├── SKILL.md           # Frontmatter metadata + instructions
└── reference/         # Optional supplementary docs
    └── *.md
```

Two execution modes:

- **Inline skills** — instructions are injected into the conversation. Low token cost. Good for conventions and patterns.
- **Forked skills** (`context: fork`) — run in an isolated subprocess. Don't pollute your main context. Good for long-running tasks like reviews, audits, and code generation.

Skills with `user-invocable: true` in their frontmatter appear as `/slash-commands`.

## Project Structure

```
.agents/skills/          # 48 skills (canonical location)
.claude/skills/          # Symlinks to .agents/skills/ (Claude Code discovery)
37signals_skills/        # 18 skills, 37signals/Basecamp style
skill_vs_agent.md        # Decision guide: skill vs agent
universal_skills.md      # Agent Skills standard reference
```

## License

MIT
