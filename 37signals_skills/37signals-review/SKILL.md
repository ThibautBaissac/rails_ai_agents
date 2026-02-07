---
name: 37signals-review
description: Code review ensuring adherence to modern Rails patterns. Triggers on review, code review, check code, validate patterns.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Review Skill

## Overview

Review code for adherence to modern Rails patterns. Identify anti-patterns, suggest improvements, validate naming conventions and architecture.

## Review Checklist

### Database/Models
- [ ] Tables use UUIDs (not integer IDs)
- [ ] All tables have account_id for multi-tenancy
- [ ] No foreign key constraints
- [ ] State is records, not booleans
- [ ] Models use rich domain logic
- [ ] Concerns extract shared behavior
- [ ] Associations use `touch: true`

### Controllers
- [ ] All actions map to CRUD verbs
- [ ] Custom actions become new resources
- [ ] Business logic in models, not controllers
- [ ] All queries scope through Current.account
- [ ] Uses `fresh_when` for HTTP caching

### Views
- [ ] Uses Turbo Frames for isolated updates
- [ ] Uses Turbo Streams for real-time
- [ ] Stimulus controllers are single-purpose
- [ ] Fragment caching with cache keys

### Jobs
- [ ] Uses Solid Queue (not Sidekiq)
- [ ] Follows _later/_now convention
- [ ] Idempotent (safe to retry)

### Tests
- [ ] Uses Minitest (not RSpec)
- [ ] Uses fixtures (not factories)
- [ ] Tests behavior, not implementation

## Anti-Pattern Detection

### 1. Custom Controller Actions
```ruby
# ❌ Anti-pattern
def archive
  @project.update(archived: true)
end

# ✅ Pattern
class ArchivalsController
  def create
    @project.create_archival!
  end
end
```

### 2. Service Objects
```ruby
# ❌ Anti-pattern
class ProjectCreationService
  def call
    # business logic
  end
end

# ✅ Pattern
class Project < ApplicationRecord
  def self.create_with_defaults(...)
    # business logic in model
  end
end
```

### 3. Boolean Flags
```ruby
# ❌ Anti-pattern
closed: boolean
closed_at: datetime

# ✅ Pattern
has_one :closure
scope :closed, -> { joins(:closure) }
```

### 4. Missing Account Scoping
```ruby
# ❌ Security vulnerability
Project.find(params[:id])

# ✅ Pattern
Current.account.projects.find(params[:id])
```

### 5. No HTTP Caching
```ruby
# ❌ Missing
def show
  @project = find_project
end

# ✅ Pattern
def show
  @project = find_project
  fresh_when @project
end
```

### 6. Fat Controllers
```ruby
# ❌ Anti-pattern
def create
  @comment = @card.comments.build(params)
  if @comment.body.match?(/@\w+/)
    # parse mentions
    # send notifications
  end
  @comment.save!
end

# ✅ Pattern
def create
  @card.comments.create!(comment_params)
end

# Mentions/notifications in model callbacks
```

## Review Feedback Format

```markdown
## Summary
[One-sentence assessment]

## Critical Issues ❌
### 1. [Issue]
**File:** path/to/file.rb:123

**Current:**
```ruby
[problematic code]
```

**Fix:**
```ruby
[corrected code]
```

**Why:** [explanation]

## Suggestions ⚠️
[Nice-to-have improvements]

## Praise ✅
[What was done well]
```

## Quick Reference

| Anti-Pattern | Pattern |
|--------------|---------|
| Custom actions | New CRUD resource |
| Service objects | Model methods |
| Boolean flags | State records |
| Fat controllers | Logic in models |
| Duplicate code | Extract concern |
| No account scoping | Current.account |
| No HTTP caching | fresh_when |
| RSpec + factories | Minitest + fixtures |
| Sidekiq + Redis | Solid Queue |
| Integer IDs | UUIDs |

## Boundaries

### Always
- Provide specific, actionable feedback
- Include code examples
- Explain the "why"
- Link to relevant patterns
- Acknowledge good work

### Never
- Be vague ("this is bad")
- Block without solutions
- Focus on trivial style issues
- Miss security vulnerabilities
