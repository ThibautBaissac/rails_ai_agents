---
paths:
  - "app/**/*.rb"
  - "lib/**/*.rb"
---

# 37signals Ruby Style

- Expanded conditionals over guard clauses (exception: single-line early returns at method start when body is non-trivial)
- Method ordering: class methods > public instance (`initialize` first) > private
- Order private methods vertically by invocation flow (call order matches read order)
- Bang methods (`!`) only when a non-bang counterpart exists; never to flag destructiveness
- No newline under `private`/`protected` keyword; indent content under it
- If a module has only private methods: `private` at top, extra newline after, no indentation
- Prefer string enums over integers
- Use `normalizes` for data cleanup (strip, downcase)
- Default values via lambdas: `default: -> { Current.user }`
- No service objects -- business logic belongs in models
