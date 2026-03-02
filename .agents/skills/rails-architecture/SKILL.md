---
name: rails-architecture
description: >-
  Guides modern Rails 8 code architecture decisions and patterns. Use when
  deciding where to put code, choosing between patterns (service objects vs
  concerns vs query objects), designing feature architecture, refactoring
  for better organization, or when user mentions architecture, code
  organization, design patterns, or layered design.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Modern Rails 8 Architecture Patterns

## Overview

Rails 8 follows "convention over configuration" with a layered architecture that separates concerns. This skill guides architectural decisions for clean, maintainable code.

## Architecture Decision Tree

```
Where should this code go?
│
├─ Is it view/display formatting?
│   └─ → Presenter (see: rails-presenter skill)
│
├─ Is it complex business logic?
│   └─ → Service Object (see: rails-service-object skill)
│
├─ Is it a complex database query?
│   └─ → Query Object (see: rails-query-object skill)
│
├─ Is it shared behavior across models?
│   └─ → Concern (see: rails-concern skill)
│
├─ Is it authorization logic?
│   └─ → Policy (see: authorization-pundit skill)
│
├─ Is it reusable UI with logic?
│   └─ → ViewComponent (see: viewcomponent-patterns skill)
│
├─ Is it async/background work?
│   └─ → Job (see: solid-queue-setup skill)
│
├─ Is it a complex form (multi-model, wizard)?
│   └─ → Form Object (see: form-object-patterns skill)
│
├─ Is it a transactional email?
│   └─ → Mailer (see: action-mailer-patterns skill)
│
├─ Is it real-time/WebSocket communication?
│   └─ → Channel (see: action-cable-patterns skill)
│
├─ Is it data validation only?
│   └─ → Model (see: rails-model-generator skill)
│
└─ Is it HTTP request/response handling only?
    └─ → Controller (see: rails-controller skill)
```

## Layer Interaction Flow

```
┌─────────────────────────────────────────────────────────────┐
│                        REQUEST                               │
└─────────────────────────┬───────────────────────────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                     CONTROLLER                               │
│  • Authenticate (Authentication concern)                     │
│  • Authorize (Policy)                                        │
│  • Parse params                                              │
│  • Delegate to Service/Query                                 │
└──────────┬─────────────────────────────────┬────────────────┘
           │                                 │
           ▼                                 ▼
┌─────────────────────┐           ┌─────────────────────┐
│      SERVICE        │           │       QUERY         │
│  • Business logic   │           │  • Complex queries  │
│  • Orchestration    │           │  • Aggregations     │
│  • Transactions     │           │  • Reports          │
└──────────┬──────────┘           └──────────┬──────────┘
           │                                 │
           ▼                                 ▼
┌─────────────────────────────────────────────────────────────┐
│                        MODEL                                 │
│  • Validations  • Associations  • Scopes  • Callbacks       │
└─────────────────────────┬───────────────────────────────────┘
                          │
           ┌──────────────┴──────────────┐
           ▼                             ▼
┌─────────────────────┐       ┌─────────────────────┐
│     PRESENTER       │       │    VIEW COMPONENT   │
│  • Formatting       │       │  • Reusable UI      │
│  • Display logic    │       │  • Encapsulated     │
└──────────┬──────────┘       └──────────┬──────────┘
           │                             │
           └──────────────┬──────────────┘
                          ▼
┌─────────────────────────────────────────────────────────────┐
│                       RESPONSE                               │
└─────────────────────────────────────────────────────────────┘

ASYNC FLOWS:
┌─────────────────────┐       ┌─────────────────────┐
│        JOB          │       │      CHANNEL        │
│  • Background work  │       │  • Real-time        │
│  • Solid Queue      │       │  • WebSockets       │
└─────────────────────┘       └─────────────────────┘

EMAIL FLOWS:
┌─────────────────────┐
│       MAILER        │
│  • Transactional    │
│  • Notifications    │
└─────────────────────┘
```

See [layer-interactions.md](references/layer-interactions.md) for detailed examples.

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

## Project Directory Structure

```
app/
├── channels/            # Action Cable channels
├── components/          # ViewComponents (UI + logic)
├── controllers/
│   └── concerns/        # Shared controller behavior
├── forms/               # Form objects
├── helpers/             # Simple view helpers (avoid)
├── jobs/                # Background jobs (Solid Queue)
├── mailers/             # Action Mailer classes
├── models/
│   └── concerns/        # Shared model behavior
├── policies/            # Pundit authorization
├── presenters/          # View formatting
├── queries/             # Complex queries
├── services/            # Business logic
│   └── result.rb        # Shared Result class
└── views/
    └── layouts/
        └── mailer.html.erb  # Email layout
```

## Core Principles

### 1. Skinny Controllers

Controllers should only:
- Authenticate/authorize
- Parse params
- Call service/query
- Render response

```ruby
# GOOD: Thin controller
class OrdersController < ApplicationController
  def create
    result = Orders::CreateService.new.call(
      user: current_user,
      params: order_params
    )

    if result.success?
      redirect_to result.data, notice: t(".success")
    else
      flash.now[:alert] = result.error
      render :new, status: :unprocessable_entity
    end
  end
end

# BAD: Fat controller with business logic
class OrdersController < ApplicationController
  def create
    @order = Order.new(order_params)
    @order.user = current_user

    if @order.valid?
      inventory_available = @order.items.all? do |item|
        Product.find(item.product_id).inventory >= item.quantity
      end

      if inventory_available
        # ... more logic
      end
    end
  end
end
```

### 2. Rich Models, Smart Services

Models handle:
- Validations
- Associations
- Scopes
- Simple derived attributes

Services handle:
- Multi-model operations
- External API calls
- Complex business rules
- Transactions across models

### 3. Result Objects for Services

All services return a consistent Result object using Ruby 3.2+ `Data.define`:

```ruby
Result = Data.define(:success, :data, :error) do
  def success? = success
  def failure? = !success
end
```

### 4. Multi-Tenancy by Default

All queries scoped through account:

```ruby
# GOOD: Scoped through account
def index
  @events = current_account.events.recent
end

# BAD: Unscoped query
def index
  @events = Event.where(user_id: current_user.id)
end
```

## When NOT to Abstract (Avoid Over-Engineering)

| Situation | Keep It Simple | Don't Create |
|-----------|----------------|--------------|
| Simple CRUD (< 10 lines) | Keep in controller | Service object |
| Used only once | Inline the code | Abstraction |
| Simple query with 1-2 conditions | Model scope | Query object |
| Basic text formatting | Helper method | Presenter |
| Single model form | `form_with model:` | Form object |
| Simple partial without logic | Partial | ViewComponent |

### Signs of Over-Engineering

```ruby
# OVER-ENGINEERED: Service for simple save
class Users::UpdateEmailService
  def call(user, email)
    user.update(email: email)  # Just do this in controller!
  end
end

# KEEP IT SIMPLE
class UsersController < ApplicationController
  def update
    if @user.update(user_params)
      redirect_to @user
    else
      render :edit
    end
  end
end
```

### When TO Abstract

| Signal | Action |
|--------|--------|
| Same code in 3+ places | Extract to concern/service |
| Controller action > 15 lines | Extract to service |
| Model > 300 lines | Extract concerns |
| Complex conditionals | Extract to policy/service |
| Query joins 3+ tables | Extract to query object |
| Form spans multiple models | Extract to form object |

## Pattern Selection Guide

### Use Service Objects When:

- Logic spans multiple models
- External API calls needed
- Complex business rules
- Need consistent error handling
- Logic reused across controllers/jobs

→ See **rails-service-object** skill for details.

### Use Query Objects When:

- Complex SQL/ActiveRecord queries
- Aggregations and statistics
- Dashboard data
- Reports

→ See **rails-query-object** skill for details.

### Use Presenters When:

- Formatting data for display
- Status badges with colors
- Currency/date formatting
- Conditional display logic

→ See **rails-presenter** skill for details.

### Use Concerns When:

- Shared validations across models
- Common scopes (e.g., `Searchable`)
- Shared callbacks (e.g., `HasUuid`)
- Keep it single-purpose!

→ See **rails-concern** skill for details.

### Use ViewComponents When:

- Reusable UI with logic
- Complex partials
- Need testable views
- Cards, tables, badges

→ See **viewcomponent-patterns** skill for details.

### Use Form Objects When:

- Multi-model forms
- Wizard/multi-step forms
- Search/filter forms
- Contact forms (no persistence)

→ See **form-object-patterns** skill for details.

### Use Policies When:

- Resource authorization
- Role-based access
- Action permissions
- Scoped collections

→ See **authorization-pundit** skill for details.

## Rails 8 Specific Features

### Authentication (Built-in Generator)

```bash
bin/rails generate authentication
```

Uses `has_secure_password` with Session model, Current class, and password reset flow.

→ See **authentication-flow** skill for details.

### Background Jobs (Solid Queue)

Database-backed job processing, no Redis required.

→ See **solid-queue-setup** skill for details.

### Real-time (Action Cable + Solid Cable)

WebSocket support with database-backed adapter.

→ See **action-cable-patterns** skill for details.

### Caching (Solid Cache)

Database-backed caching, no Redis required.

→ See **caching-strategies** skill for details.

### Other Rails 8 Defaults

| Feature | Purpose |
|---------|---------|
| **Propshaft** | Asset pipeline (replaces Sprockets) |
| **Importmap** | JavaScript without bundling |
| **Kamal** | Docker deployment |
| **Thruster** | HTTP/2 proxy with caching |

## Anti-Patterns to Avoid

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| God Model | Model > 500 lines | Extract services/concerns |
| Fat Controller | Logic in controllers | Move to services |
| Callback Hell | Complex model callbacks | Use services |
| Helper Soup | Massive helper modules | Use presenters/components |
| N+1 Queries | Unoptimized queries | Use `.includes()`, query objects |
| Stringly Typed | Magic strings everywhere | Use constants, enums |
| Premature Abstraction | Service for 3 lines | Keep in controller |

→ See **performance-optimization** skill for N+1 detection.

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
| Form | Unit | Validations, persistence |
| System | E2E | Critical user paths |

→ See **tdd-cycle** skill for TDD workflow.

## Quick Reference

### New Feature Checklist

1. **Model** - Define data structure
2. **Policy** - Add authorization rules
3. **Service** - Create for complex logic (if needed)
4. **Query** - Add for complex queries (if needed)
5. **Controller** - Keep it thin!
6. **Form** - Use for multi-model forms (if needed)
7. **Presenter** - Format for display
8. **Component** - Build reusable UI
9. **Mailer** - Add transactional emails (if needed)
10. **Job** - Add background processing (if needed)

### Refactoring Signals

| Signal | Action |
|--------|--------|
| Model > 300 lines | Extract concern or service |
| Controller action > 15 lines | Extract service |
| View logic in helpers | Use presenter |
| Repeated query patterns | Extract query object |
| Complex partial with logic | Use ViewComponent |
| Form with multiple models | Use form object |
| Same code in 3+ places | Extract to shared module |

## Related Skills

| Category | Skills |
|----------|--------|
| **Data Layer** | rails-model-generator, rails-query-object, database-migrations |
| **Business Logic** | rails-service-object, rails-concern, form-object-patterns |
| **Presentation** | rails-presenter, viewcomponent-patterns |
| **Controllers** | rails-controller, api-versioning |
| **Auth** | authentication-flow, authorization-pundit |
| **Background** | solid-queue-setup, action-mailer-patterns |
| **Real-time** | action-cable-patterns, hotwire-patterns |
| **Performance** | caching-strategies, performance-optimization |
| **I18n** | i18n-patterns |
| **Testing** | tdd-cycle |

## References

- See [layer-interactions.md](references/layer-interactions.md) for layer communication patterns
- See [service-patterns.md](references/service-patterns.md) for service object patterns
- See [query-patterns.md](references/query-patterns.md) for query object patterns
- See [error-handling.md](references/error-handling.md) for error handling strategies
- See [testing-strategy.md](references/testing-strategy.md) for comprehensive testing
