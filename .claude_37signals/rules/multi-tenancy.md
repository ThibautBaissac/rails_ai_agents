---
paths:
  - "app/models/**/*.rb"
  - "app/controllers/**/*.rb"
  - "app/jobs/**/*.rb"
  - "db/migrate/**/*.rb"
  - "config/routes.rb"
---

# Multi-Tenancy Conventions (37signals)

- URL path-based: `/:account_id/resources`
- `account_id` on every table for data isolation
- All queries scope through `Current.account`
- `belongs_to :account, default: -> { parent.account }` for child models
- No default scopes for tenancy -- always scope explicitly
- Tests must verify cross-account data isolation
- UUIDs prevent enumeration attacks on account IDs
- Background jobs automatically serialize/restore `Current.account`
- Middleware extracts account from URL and sets `Current.account`
