---
globs: "db/migrate/**/*.rb, db/schema.rb"
---

# Migration Conventions

- Always reversible: prefer `change` over `up`/`down`
- Add `null: false` for required columns
- Add database-level defaults where appropriate
- Always add indexes for foreign keys and frequently queried columns
- Add unique indexes for uniqueness validations
- Use `references` with `foreign_key: true` for associations
- Never modify a migration that has already been run -- create a new one
- For zero-downtime: add column first, then backfill, then add constraint
