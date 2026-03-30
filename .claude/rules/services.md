---
globs: "app/services/**/*.rb, spec/services/**/*.rb"
---

# Service Object Conventions

- Single public method: `#call`
- Class-level shortcut: `self.call(...)` delegates to `new(...).call`
- Return a Result object (`Data.define(:success, :data, :error)` with `success?`/`failure?` predicates)
- Never raise exceptions for business logic failures; use `failure(message)`
- Namespace by domain: `Entities::CreateService`, `Orders::CancelService`
- Inherit from `ApplicationService` base class (`app/services/application_service.rb`)
- Inject dependencies via constructor for testability
- Wrap multi-model operations in `ActiveRecord::Base.transaction`
- Test both success and failure paths with `subject(:result)`
