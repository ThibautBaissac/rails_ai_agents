---
paths:
  - "app/controllers/**/*.rb"
  - "test/controllers/**/*.rb"
  - "config/routes.rb"
---

# Controller Conventions (37signals)

- Only 7 REST actions: index, show, new, create, edit, update, destroy
- Never add custom actions; create new resource controllers instead
- State changes become singular resources: `resource :closure` (POST to close, DELETE to reopen)
- Thin controllers: call model methods directly, no business logic
- All queries scope through `Current.account`
- Use concerns for shared scoping (`CardScoped`, `BoardScoped`)
- Use `fresh_when` and `stale?` for HTTP caching with ETags
- Use `respond_to` with `format.turbo_stream` and `format.html`
- Use `scope module:` for namespacing nested resources
