# 37signals Rails Configuration

## Tech Stack

- **Ruby** 3.3, **Rails** 8.2 (edge), **MySQL** (SaaS) / **SQLite** (OSS)
- **Frontend:** Hotwire (Turbo 8 + Stimulus 3.2), Importmap (no Node.js)
- **Testing:** Minitest + Fixtures (not RSpec, not FactoryBot)
- **Auth:** Custom passwordless: passkeys (WebAuthn) + magic links (no Devise), `has_secure_password` optional
- **Background Jobs:** Solid Queue (database-backed, no Redis)
- **Caching:** Solid Cache | **WebSockets:** Solid Cable
- **IDs:** UUIDv7 everywhere (base36-encoded, 25-char strings)
- **Assets:** Propshaft + Import Maps (no Node.js, no Webpack)
- **Deployment:** Kamal 2 + Thruster

## Architecture

```
app/
  controllers/     # Thin. Only 7 REST actions. New resource for each state change.
  models/          # Rich. Business logic, concerns, associations, validations.
  models/concerns/ # Horizontal behavior: Closeable, Assignable, Searchable.
  views/           # ERB + Turbo Frames/Streams. No JS frameworks.
  jobs/            # Shallow. Call model methods, don't contain logic.
  mailers/         # Minimal. Bundle notifications, plain-text first.
  channels/        # ActionCable channels for real-time.
```

**No `app/services/`, `app/queries/`, `app/policies/`, `app/forms/` directories.** Business logic lives in models. Authorization via roles on User model + controller concerns. Complex forms use standard Rails nested attributes.

## Core Philosophy

- **Vanilla Rails:** Rich domain models, thin controllers, avoid service objects (acceptable when justified, but not as default architecture), no Devise, no Pundit
- **Everything is CRUD:** State changes = new resources (`Closure`, `Publication`, `Archival`)
- **State as records:** No boolean flags for business state -- use `has_one` state records
- **Rich models over services:** Business logic lives in models, organized via concerns
- **Concerns for organization:** Models compose behavior via focused concerns (`Closeable`, `Assignable`)
- **No foreign key constraints:** Application enforces referential integrity
- **Multi-tenancy:** URL path-based (`/:account_id/...`), `account_id` on every table
- **Current for context:** `Current.user`, `Current.account`, `Current.session`
- **Shallow jobs:** `_later`/`_now` pattern; job calls model method, logic stays in model

## Key Commands

```bash
bin/setup                                    # Initial setup
bin/dev                                      # Start dev server
bin/rails test                               # Full test suite
bin/rails test test/models/card_test.rb      # Specific file
bin/rails test test/models/card_test.rb:14   # Specific line
bin/rails test:system                        # System tests (Capybara + Selenium)
bin/ci                                       # Full CI (rubocop + brakeman + tests)
bundle exec rubocop -a                       # Auto-fix Ruby style
bin/rails db:migrate                         # Run migrations
bin/rails db:fixtures:load                   # Load fixture data
bin/rails db:reset                           # Drop, create, load schema + fixtures
```

## Development Workflow

1. Write a failing Minitest test with fixtures
2. Implement minimal code to make it pass
3. Refactor while tests stay green

## Naming Conventions

| Layer | Pattern | Example |
|-------|---------|---------|
| Model | Singular PascalCase | `Card`, `BoardPublication` |
| Controller | Plural, nested by resource | `Cards::ClosuresController` |
| State Record | Noun describing state | `Closure`, `Publication`, `Goldness` |
| Concern | Adjective/-able | `Closeable`, `Assignable`, `Searchable` |
| Job | `Model::VerbJob` | `Event::RelayJob`, `Card::CleanupJob` |
| Test | `ModelTest` / `ControllerTest` | `CardTest`, `Cards::ClosuresControllerTest` |

## Style Guide (37signals)

- Expanded conditionals over guard clauses (exception: single-line early returns at method start)
- Method ordering: class methods > public instance (`initialize` first) > private
- Order private methods by invocation flow (call order)
- Bang methods (`!`) only when a non-bang counterpart exists
- No newline under `private`/`protected` keyword; indent content under it
- Avoid service objects -- domain logic belongs in models with concerns (services acceptable when justified)
- `belongs_to :creator, default: -> { Current.user }` for context defaults
- `touch: true` on child associations for cache invalidation

See @../rails-development-principles.md for full development principles.
