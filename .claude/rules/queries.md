---
globs: "app/queries/**/*.rb, spec/queries/**/*.rb"
---

# Query Object Conventions

- Single responsibility: one query concern per class
- Accept context via constructor (`account:` or `user:` for multi-tenancy)
- Return `ActiveRecord::Relation` for chainability, or `Hash` for aggregations
- Public method: `#call` with optional filter parameters
- Always use `includes`/`preload`/`eager_load` to prevent N+1 queries
- Never modify data in queries -- read-only
- Sanitize user input: `sanitize_sql_like()`, parameterized queries
- Simple one-liner queries should stay as model scopes
- Test multi-tenant isolation: account A cannot see account B data
