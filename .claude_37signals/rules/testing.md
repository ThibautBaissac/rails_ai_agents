---
paths:
  - "test/**/*.rb"
  - "test/fixtures/**/*.yml"
---

# Testing Conventions (37signals)

- Minitest only, never RSpec
- Fixtures only, never FactoryBot (10-100x faster)
- Integration tests over isolated unit tests
- Use `fixtures(:name)` not `create`/`build`
- Test behavior and outcomes, not implementation details
- `setup` block for shared state and `Current` attributes
- `assert`/`refute` over `expect`/`should`
- One assertion focus per test (one concept, can have multiple asserts)
- System tests with Capybara + Selenium for full user workflows
- Fixture YAML supports ERB for dynamic data
- Test cross-account isolation in multi-tenant tests
