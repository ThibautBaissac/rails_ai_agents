---
paths:
  - "app/models/**/*.rb"
  - "test/models/**/*.rb"
---

# Model Conventions (37signals)

- Rich domain models: business logic in models, NOT service objects
- Concerns for horizontal behavior (`Closeable`, `Assignable`, `Searchable`, `Eventable`)
- State as records, not booleans: `has_one :closure` instead of `closed: boolean`
- `belongs_to` defaults via lambdas: `default: -> { Current.user }`
- `touch: true` on child->parent associations for cache invalidation
- No foreign key constraints in database; app enforces integrity
- Every model has `account_id` for multi-tenancy
- Use `where.missing(:association)` for negative state scopes (e.g., "not closed")
- `_later`/`_now` convention for async/sync method pairs
- Model methods are the public API that controllers call directly
- Keep concerns narrowly focused on one behavior each
