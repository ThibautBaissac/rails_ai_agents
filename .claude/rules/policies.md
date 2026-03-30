---
globs: "app/policies/**/*.rb, spec/policies/**/*.rb"
---

# Pundit Policy Conventions

- One policy per model: `app/policies/entity_policy.rb`
- Default deny: return `false` unless explicitly allowed
- Define a `Scope` class for `policy_scope` queries (multi-tenant filtering)
- Test every action for every role (admin, owner, user, visitor)
- Controllers must call `authorize @resource` on every action
- Use `policy_scope(Model)` instead of `Model.all` in index actions
- Inheritance: `class EntityPolicy < ApplicationPolicy`
