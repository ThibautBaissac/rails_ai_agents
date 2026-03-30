---
globs: "app/models/**/*.rb, spec/models/**/*.rb, spec/factories/**/*.rb"
---

# Model Conventions

- Keep models thin: data, validations, associations, scopes, simple predicates only
- Complex business logic goes in service objects (`app/services/`)
- Use callbacks only for data normalization (`before_validation`) and defaults (`after_initialize`)
- Side effects (emails, API calls, job enqueueing) belong in services, not callbacks
- Always specify `dependent:` on `has_many`/`has_one` associations
- Use `enum :status, { draft: 0, published: 1 }` (hash syntax with explicit integers)
- Validate presence at both model and database level (`null: false` in migration)
- Use scopes for reusable queries; use query objects (`app/queries/`) for complex ones
- Every model must have a factory in `spec/factories/` with traits for each state
- Test with Shoulda Matchers: `validate_presence_of`, `belong_to`, `have_many`
