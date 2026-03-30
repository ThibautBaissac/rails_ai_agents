---
globs: "app/**/*.rb, spec/**/*.rb"
---

# Anti-Patterns to Avoid

- **God Model**: If a model exceeds ~200 lines, extract business logic to services and complex queries to query objects. The model keeps only persistence, validations, associations, and simple scopes.
- **Service Graveyard**: Don't create services for trivial CRUD. `user.update!(name: params[:name])` is fine inline. The bar for extraction is real complexity.
- **Callback Spaghetti**: Never chain `after_create`/`after_save` for emails, jobs, APIs, or creating related records. These are contextual side effects that belong in explicit service calls.
- **STI Abuse**: If more than 20% of columns are subtype-specific (lots of NULLs), use polymorphic associations with separate tables instead.
- **N+1 Ignorance**: Always eager-load associations you know you'll access (`includes`, `preload`). Use `strict_loading` to catch lazy loads in development.
- **Kitchen Sink Concern**: Concerns must be narrow and focused (e.g., `SoftDeletable`, `Sluggable`). If a concern exceeds ~30 lines or has multiple responsibilities, it's a service object in disguise.
