---
name: rails-architecture
description: >-
  Guides modern Rails 8 code architecture decisions and patterns. Use when
  deciding where to put code, choosing between patterns (service objects vs
  concerns vs query objects), designing feature architecture, refactoring
  for better organization, or when user mentions architecture, code
  organization, design patterns, or layered design. WHEN NOT: Implementing
  specific patterns (use specialist agents like service-agent or query-agent),
  writing tests, or debugging runtime errors.
model: sonnet
effort: high
---

# Modern Rails 8 Architecture Patterns

## Architecture Decision Tree

```
Where should this code go?
|
+- View/display formatting?       -> Presenter (@presenter-agent)
+- Complex business logic?        -> Service Object (@service-agent)
+- Complex database query?        -> Query Object (@query-agent)
+- Shared behavior across models? -> Concern (/rails-concern skill)
+- Authorization logic?           -> Policy (@policy-agent)
+- Reusable UI with logic?        -> ViewComponent (@viewcomponent-agent)
+- Async/background work?         -> Job (@job-agent, /solid-queue-setup skill)
+- Complex form (multi-model)?    -> Form Object (@form-agent)
+- Transactional email?           -> Mailer (@mailer-agent)
+- Real-time/WebSocket?           -> Channel (/action-cable-patterns skill)
+- Data validation only?          -> Model (@model-agent)
+- HTTP request/response only?    -> Controller (@controller-agent)
```

## Layer Responsibilities

| Layer | Responsibility | Should NOT contain |
|-------|---------------|-------------------|
| **Controller** | HTTP, params, response | Business logic, queries |
| **Model** | Data, validations, relations | Display logic, HTTP |
| **Service** | Business logic, orchestration | HTTP, display logic |
| **Query** | Complex database queries | Business logic |
| **Presenter** | View formatting, badges | Business logic, queries |
| **Policy** | Authorization rules | Business logic |
| **Component** | Reusable UI encapsulation | Business logic |
| **Job** | Async processing | HTTP, display logic |
| **Form** | Complex form handling | Persistence logic |
| **Mailer** | Email composition | Business logic |
| **Channel** | WebSocket communication | Business logic |

## When NOT to Abstract

| Situation | Keep It Simple | Don't Create |
|-----------|----------------|--------------|
| Simple CRUD (< 10 lines) | Keep in controller | Service object |
| Used only once | Inline the code | Abstraction |
| Simple query with 1-2 conditions | Model scope | Query object |
| Basic text formatting | Helper method | Presenter |
| Single model form | `form_with model:` | Form object |
| Simple partial without logic | Partial | ViewComponent |

## When TO Abstract

| Signal | Action |
|--------|--------|
| Same code in 3+ places | Extract to concern/service |
| Controller action > 15 lines | Extract to service |
| Model > 300 lines | Extract concerns |
| Complex conditionals | Extract to policy/service |
| Query joins 3+ tables | Extract to query object |
| Form spans multiple models | Extract to form object |

See /extraction-timing skill for detailed extraction guidance.

## Core Patterns

### Skinny Controllers

```ruby
# GOOD: Thin controller delegates to service
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.call(user: current_user, params: order_params)
    if result.success?
      redirect_to result.data, notice: t(".success")
    else
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end
end
```

### Result Objects for Services

All services return a consistent Result object:

```ruby
Result = Data.define(:success, :data, :error) do
  def success? = success
  def failure? = !success
end
```

### Multi-Tenancy by Default

```ruby
# GOOD: Scoped through account
def index
  @events = current_account.events.recent
end
```

## Rails 8 Specific Features

| Feature | Purpose | Skill/Agent |
|---------|---------|-------------|
| Authentication | `has_secure_password` generator | /authentication-flow |
| Background Jobs | Solid Queue (database-backed) | /solid-queue-setup, @job-agent |
| Real-time | Action Cable + Solid Cable | /action-cable-patterns |
| Caching | Solid Cache (database-backed) | /caching-strategies |
| Assets | Propshaft + Import Maps | (built-in) |
| Deployment | Kamal 2 + Thruster | (built-in) |

## Testing Strategy by Layer

| Layer | Test Type | Focus |
|-------|-----------|-------|
| Model | Unit | Validations, scopes, methods |
| Service | Unit | Business logic, edge cases |
| Query | Unit | Query results, tenant isolation |
| Presenter | Unit | Formatting, HTML output |
| Controller | Request | Integration, HTTP flow |
| Component | Component | Rendering, variants |
| Policy | Unit | Authorization rules |
| System | E2E | Critical user paths |

## New Feature Checklist

1. **Model** - Define data structure (@migration-agent, @model-agent)
2. **Policy** - Add authorization rules (@policy-agent)
3. **Service** - Create for complex logic (@service-agent)
4. **Query** - Add for complex queries (@query-agent)
5. **Controller** - Keep it thin (@controller-agent)
6. **Presenter** - Format for display (@presenter-agent)
7. **Component** - Build reusable UI (@viewcomponent-agent)
8. **Mailer** - Add transactional emails (@mailer-agent)
9. **Job** - Add background processing (@job-agent)

## References

- See [layer-interactions.md](references/layer-interactions.md) for layer communication patterns
- See [service-patterns.md](references/service-patterns.md) for service object patterns
- See [query-patterns.md](references/query-patterns.md) for query object patterns
- See [error-handling.md](references/error-handling.md) for error handling strategies
- See [testing-strategy.md](references/testing-strategy.md) for comprehensive testing
