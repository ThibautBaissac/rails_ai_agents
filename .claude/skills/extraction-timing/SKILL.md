---
name: extraction-timing
description: >-
  Guides decisions about when and how to extract code into services, queries,
  concerns, form objects, or other patterns. Use when deciding whether to
  extract code, choosing between patterns (service vs concern vs query),
  evaluating if a base class or abstraction is needed, or when user mentions
  refactoring, extraction, code organization, or "where should this go."
  WHEN NOT: Implementing a specific pattern already decided on (use specialist
  agents like service-agent, query-agent, or model-agent), writing tests
  (use rspec-agent), or architecture-level design (use rails-architecture).
user-invocable: false
---

You are an expert in Rails code organization and extraction decisions. Help decide **when** to extract, **what pattern** to use, and **when to keep it simple**.

## Core Philosophy: Skinny Everything

The 2025 Rails consensus has evolved beyond "Fat Models" to **Skinny Everything**:
- **Controllers**: orchestrate (delegate to services, render responses) -- max ~10 lines per action
- **Models**: persist (validations, associations, scopes, simple predicates) -- max ~100 lines
- **Services**: contain business logic (multi-step operations, external calls, orchestration)
- **Views**: display markup with zero logic

## Extraction Thresholds

| Signal | Action |
|--------|--------|
| Controller action exceeds ~10 lines of business logic | Extract to service object |
| Model exceeds ~100 lines | Extract business logic to services, complex queries to query objects |
| Query joins multiple tables or has conditional clauses | Extract to query object |
| Form touches multiple models or has custom validation | Extract to form object |
| Display formatting logic in model | Extract to presenter |
| UI element reused across 2+ views | Extract to ViewComponent |
| Shared behavior across 2+ models (narrow, simple) | Extract to concern |
| 5+ concrete implementations with identical structure | Extract base class |
| One-off operation | **Don't extract. Inline is fine.** |

## Decision Tree: "Where Should This Code Go?"

```
Is it a database query?
  ├── Simple (one table, one condition) → Model scope
  └── Complex (joins, conditionals, reused) → Query object

Is it business logic?
  ├── Simple CRUD on one model → Controller inline (or model method)
  ├── Multi-step operation → Service object
  ├── Involves external API → Service object
  └── Spans multiple models → Service object with transaction

Is it shared behavior?
  ├── Property of the model (soft-delete, slugs, search) → Concern
  └── Operation on the model (checkout, import, sync) → Service object

Is it display logic?
  ├── Formatting one model's data → Presenter (SimpleDelegator)
  ├── Reusable UI element → ViewComponent
  └── Simple helper method → Keep in helper (use sparingly)

Is it validation?
  ├── Single model, standard rules → Model validation
  ├── Multi-model form → Form object
  └── Business rule (not data integrity) → Service validation
```

## Settled Debates

### Concerns vs Service Objects

| | Concerns | Service Objects |
|--|---------|----------------|
| **Use for** | Simple shared model properties | Multi-step business operations |
| **Examples** | `SoftDeletable`, `Searchable`, `Sluggable` | `CreateOrder`, `ProcessRefund`, `ImportCsv` |
| **Max size** | ~30 lines | No hard limit (but SRP applies) |
| **Test via** | Including model's specs | Isolated unit specs |

**Rule:** If the behavior is a *property* of the model, use a concern. If it's an *operation* on the model, use a service.

### STI vs Polymorphic Associations

| | STI | Polymorphic |
|--|-----|------------|
| **Use when** | Subclasses share >80% of columns | Types have unique attributes |
| **Table** | One shared table with `type` column | Separate tables per type |
| **Avoid when** | >20% columns are NULL for some subtypes | Types are fundamentally similar |

### Callbacks vs Explicit Calls

**Rule:** Callbacks for data normalization only. Everything else is explicit.

| Acceptable Callbacks | Must Be Explicit (in services) |
|---------------------|-------------------------------|
| `before_validation :strip_whitespace` | Sending emails |
| `before_save :downcase_email` | Enqueuing background jobs |
| `before_destroy :check_dependencies` | Calling external APIs |
| `after_initialize :set_defaults` | Creating related records with business logic |

## Anti-Pattern Checklist

Before extracting, verify you're not creating:
- [ ] A service that wraps a single `model.update!` call (Service Graveyard)
- [ ] A base class for only 2 services (Premature Abstraction)
- [ ] A concern with multiple responsibilities (Kitchen Sink Concern)
- [ ] A helper that should be a presenter or component
- [ ] An abstraction for a hypothetical future need (YAGNI violation)

## Reference

See @docs/rails-development-principles.md for the complete development principles guide including SOLID, testing strategy, security, and performance.
