---
paths:
  - "app/mailers/**/*.rb"
  - "app/views/*_mailer/**/*"
  - "test/mailers/**/*.rb"
---

# Mailer Conventions (37signals)

- Plain-text first, HTML optional with minimal inline CSS
- Bundle notifications: 1 digest email instead of N individual emails
- Always `deliver_later` (never `deliver_now` in production code)
- Transactional emails only (no marketing)
- Email previews for development (`test/mailers/previews/`)
- Shallow mailers: format and deliver, logic stays in models
- Mailers are called from jobs (not directly from controllers); see rules/jobs.md for the `_later`/`_now` pattern
