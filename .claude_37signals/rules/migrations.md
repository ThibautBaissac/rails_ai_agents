---
paths:
  - "db/migrate/**/*.rb"
  - "db/schema.rb"
---

# Migration Conventions (37signals)

- UUIDs as primary keys: `id: :uuid`
- `account_id` (type: `:uuid`) on every table
- References use `type: :uuid`
- No foreign key constraints (explicitly omit `foreign_key: true`)
- Composite indexes for common query patterns: `add_index :cards, [:account_id, :status]`
- String columns for enums (not integers)
- Always include `timestamps`
- Simple, reversible migrations preferred
- One concern per migration
