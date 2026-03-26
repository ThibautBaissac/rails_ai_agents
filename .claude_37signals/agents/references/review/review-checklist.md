# Review Checklist

## Database / Models

- [ ] Tables use UUIDs (not integer auto-increment IDs)
- [ ] All tables have `account_id` for multi-tenancy
- [ ] No foreign key constraints (application enforces referential integrity)
- [ ] State is records, not booleans (Archival, Closure, Publication)
- [ ] Models contain rich domain logic (not delegated to service objects)
- [ ] Shared behavior extracted into concerns (Closeable, Assignable, Searchable)
- [ ] Child associations use `touch: true` for cache invalidation
- [ ] Default values use lambdas: `default: -> { Current.user }`
- [ ] Callbacks limited to: `before_validation` for normalization, `after_create_commit` / `after_update_commit` for notifications
- [ ] No complex after_save callback chains

## Controllers

- [ ] All actions map to CRUD verbs only (index, show, new, create, edit, update, destroy)
- [ ] Custom actions extracted to new resource controllers
- [ ] Business logic lives in models, not controllers
- [ ] All queries scope through `Current.account` (never `Model.find` or `Model.all`)
- [ ] Uses `fresh_when` for HTTP caching on show/index actions
- [ ] Controller concerns for shared scoping (CardScoped, ProjectScoped)
- [ ] No conditional logic beyond simple `if @resource.save`
- [ ] Strong parameters defined in private method

## Views

- [ ] Uses Turbo Frames for isolated page sections
- [ ] Uses Turbo Streams for real-time updates
- [ ] Stimulus controllers are single-purpose and small
- [ ] Fragment caching with proper cache keys
- [ ] No complex logic in views (use model methods or helpers)
- [ ] No inline JavaScript (use Stimulus controllers)
- [ ] ERB templates, no JS framework components

## Jobs

- [ ] Uses Solid Queue (not Sidekiq, Resque, or Redis-backed)
- [ ] Follows `_later` / `_now` convention on model
- [ ] Job is shallow: calls one model method, contains no business logic
- [ ] Idempotent (safe to run multiple times with same arguments)
- [ ] Uses `retry_on` with proper backoff strategy

## Tests

- [ ] Uses Minitest (not RSpec)
- [ ] Uses fixtures (not FactoryBot)
- [ ] Uses `test "descriptive name" do` blocks (not `describe/it`)
- [ ] Tests behavior, not implementation details
- [ ] Includes system tests for critical workflows
- [ ] All tests scope through accounts (multi-tenant isolation)
- [ ] Fixture data is minimal and readable
- [ ] No `let` blocks, `before` blocks, or `shared_examples`

## Security

- [ ] No secrets in source code
- [ ] All queries scope to `Current.account`
- [ ] CSRF protection enabled (not skipped)
- [ ] No SQL injection (parameterized queries, not string interpolation)
- [ ] Authorization checks present (model-level or controller concern)
- [ ] Mass assignment protection via strong parameters

## Performance

- [ ] HTTP caching with ETags (`fresh_when`)
- [ ] Fragment caching in views (`cache @resource do`)
- [ ] Eager loading to prevent N+1 (`includes`, `preload`)
- [ ] Proper database indexes on foreign keys and query columns
- [ ] Operations >500ms in background jobs
- [ ] No blocking external API calls in request cycle

## Naming Conventions

- [ ] State records are nouns: `Closure`, `Publication`, `Archival` (not `Closer`, `Publisher`)
- [ ] Controllers are plural, nested by resource: `Cards::ClosuresController`
- [ ] Concerns are adjectives/-able: `Closeable`, `Assignable`, `Searchable`
- [ ] Jobs follow `Model::VerbJob`: `Card::CleanupJob`, `Report::GenerateJob`
- [ ] Model methods are specific verbs: `archive!`, `close!`, `publish!`
- [ ] `_later` / `_now` suffixes for async method pairs

## Architecture

- [ ] No `app/services/` directory
- [ ] No `app/queries/` directory (use model scopes)
- [ ] No `app/policies/` directory (use model methods or controller concerns)
- [ ] No `app/forms/` directory (use nested attributes)
- [ ] No Devise (custom auth or magic links)
- [ ] No Pundit (inline authorization)
- [ ] No Redis (Solid Cache, Solid Queue, Solid Cable instead)
- [ ] No GraphQL (REST + Jbuilder)
- [ ] Import Maps for JavaScript (no Node.js, no Webpack)

## Multi-Tenancy

- [ ] Account scoping via URL path (`/:account_id/...`)
- [ ] `Current.account` set in ApplicationController
- [ ] Every query goes through `Current.account.resources`
- [ ] Tests verify cross-account isolation
- [ ] All new tables include `account_id` column
- [ ] Membership model connects Users to Accounts
