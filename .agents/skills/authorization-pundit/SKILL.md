---
name: authorization-pundit
description: >-
  Implements policy-based authorization with Pundit for resource access control.
  Use when adding authorization rules, checking permissions, restricting actions,
  role-based access, or when user mentions Pundit, policies, authorization,
  or permissions.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, Pundit
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Authorization with Pundit for Rails 8

## Overview

Pundit provides policy-based authorization:
- Plain Ruby policy objects
- Convention over configuration
- Easy to test
- Scoped queries for collections
- Works with any authentication system

## Quick Start

```bash
# Add to Gemfile
bundle add pundit

# Generate base files
bin/rails generate pundit:install

# Generate policy for model
bin/rails generate pundit:policy Event
```

## Project Structure

```
app/
├── policies/
│   ├── application_policy.rb    # Base policy
│   ├── event_policy.rb
│   ├── vendor_policy.rb
│   └── user_policy.rb
spec/policies/
├── event_policy_spec.rb
├── vendor_policy_spec.rb
└── user_policy_spec.rb
```

## TDD Workflow

```
Authorization Progress:
- [ ] Step 1: Write policy spec (RED)
- [ ] Step 2: Run spec (fails)
- [ ] Step 3: Implement policy
- [ ] Step 4: Run spec (GREEN)
- [ ] Step 5: Add policy to controller
- [ ] Step 6: Test integration
```

## Base Policy

```ruby
# app/policies/application_policy.rb
class ApplicationPolicy
  attr_reader :user, :record

  def initialize(user, record)
    @user = user
    @record = record
  end

  # Default: deny all
  def index?
    false
  end

  def show?
    false
  end

  def create?
    false
  end

  def new?
    create?
  end

  def update?
    false
  end

  def edit?
    update?
  end

  def destroy?
    false
  end

  class Scope
    def initialize(user, scope)
      @user = user
      @scope = scope
    end

    def resolve
      raise NotImplementedError, "Define #resolve in #{self.class}"
    end

    private

    attr_reader :user, :scope
  end
end
```

## Policy Implementation

Four policy patterns are available. See [policies.md](references/policies.md) for full implementations:

1. **Basic Policy** – owner-based access with `Scope` filtering by `account_id`
2. **Role-Based Policy** – combines `owner?`, `admin?`, `member_or_above?` predicates; admin sees all in Scope
3. **Policy with State Conditions** – gate actions on record state (`locked?`, `destroyable?`, `can_cancel?`)
4. **Headless Policy** – policy not tied to a record (dashboards, admin panels)

Also in [policies.md](references/policies.md):
- **Permitted Attributes** – role-based `permitted_attributes` for strong params
- **Nested Resource Policies** – delegate to parent resource policy (`EventPolicy.new(user, record.event).show?`)

## Controller Integration

See [controller-integration.md](references/controller-integration.md) for full examples of:

- `ApplicationController` setup with `include Pundit::Authorization`, `after_action :verify_authorized`, and `rescue_from Pundit::NotAuthorizedError`
- Full CRUD controller using `authorize @event` and `policy_scope(Event)`
- Custom action authorization: `authorize @event, :publish?`
- Skipping authorization for public pages with `skip_after_action`

## View Integration

See [views-and-testing.md](references/views-and-testing.md) for:

- ERB conditional rendering with `policy(@event).edit?`
- ViewComponent integration with `EventPolicy.new(@user, @event)`

## Testing

See [views-and-testing.md](references/views-and-testing.md) for:

- Policy spec with `permissions :show?` blocks and `permit`/`not_to permit` matchers
- `pundit-matchers` gem usage with `permit_actions` / `forbid_actions`
- Request spec testing HTTP status and redirect behavior
- I18n error message configuration and custom `rescue_from` handler

## Checklist

- [ ] Policy spec written first (RED)
- [ ] Policy inherits from ApplicationPolicy
- [ ] Scope defined for collections
- [ ] Controller uses `authorize` and `policy_scope`
- [ ] `verify_authorized` after_action enabled
- [ ] Views use `policy(@record).action?`
- [ ] Error handling configured
- [ ] Multi-tenancy enforced in Scope
- [ ] All specs GREEN

## References

- [policies.md](references/policies.md) – Policy patterns: basic, role-based, state conditions, headless, nested, permitted attributes
- [controller-integration.md](references/controller-integration.md) – ApplicationController setup, CRUD, custom actions, skip authorization
- [views-and-testing.md](references/views-and-testing.md) – ERB views, ViewComponent, policy specs, pundit-matchers, request specs, I18n errors
