---
name: 37signals-refactoring
description: Orchestrate incremental refactoring toward modern Rails patterns. Triggers on refactor, modernize, cleanup, migrate, remove Devise, replace service objects.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Refactoring Skill

## Overview

Coordinate safe, incremental refactoring toward modern Rails patterns. Never big rewrites—make small changes, run tests, commit, repeat.

## Core Philosophy

- **Incremental changes**: Small steps, not big rewrites
- **Test first**: Add tests for existing behavior before changing
- **Feature flags**: Deploy risky changes behind flags
- **Backward compatibility**: Support old and new during transition

## Refactoring Patterns

### Pattern 1: Service Objects → Model Methods

```ruby
# Before (anti-pattern)
class ProjectCreationService
  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    project = Project.create!(@params)
    project.add_member(@user, role: :owner)
    NotificationMailer.project_created(project).deliver_later
    project
  end
end

# After (pattern)
class Project < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  after_create_commit :notify_team

  def self.create_with_defaults(creator:, **attributes)
    transaction do
      project = create!(attributes.merge(creator: creator))
      project.add_member(creator, role: :owner)
      project
    end
  end

  private

  def notify_team
    NotificationMailer.project_created(self).deliver_later
  end
end
```

**Steps:**
1. Add tests for service object behavior
2. Move logic to model methods
3. Update controller to use model
4. Delete service object
5. Run tests

### Pattern 2: Booleans → State Records

```ruby
# Before
class Card < ApplicationRecord
  # closed: boolean, closed_at: datetime, closed_by_id: integer
  scope :open, -> { where(closed: false) }
end

# After
class Card < ApplicationRecord
  has_one :closure, dependent: :destroy
  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }

  def close(user: Current.user)
    create_closure!(user: user)
  end

  def closed?
    closure.present?
  end
end
```

**Steps:**
1. Create closure migration
2. Create Closure model
3. Backfill closures from booleans
4. Update model to use closure
5. Remove boolean columns

### Pattern 3: Custom Actions → CRUD Resources

```ruby
# Before
class ProjectsController < ApplicationController
  def archive
    @project.update(archived: true)
  end
end

# After
class ArchivalsController < ApplicationController
  def create
    @project.create_archival!
    redirect_to @project
  end

  def destroy
    @project.archival.destroy!
    redirect_to @project
  end
end
```

### Pattern 4: Devise → Custom Auth

**Steps:**
1. Implement custom auth alongside Devise
2. Create magic_links table
3. Test new auth system
4. Feature flag to switch systems
5. Roll out gradually
6. Remove Devise

### Pattern 5: RSpec → Minitest

```ruby
# Before (RSpec)
RSpec.describe Project do
  let(:user) { create(:user) }
  let(:project) { create(:project, creator: user) }

  it "archives project" do
    project.archive
    expect(project.archived?).to be true
  end
end

# After (Minitest)
class ProjectTest < ActiveSupport::TestCase
  test "archives project" do
    project = projects(:one)
    project.archive
    assert project.archived?
  end
end
```

**Steps:**
1. Create fixtures from factories
2. Convert one test file as example
3. Run both suites in parallel
4. Convert remaining tests
5. Remove RSpec

## Refactoring Workflow

1. **Add tests** for existing behavior
2. **Make smallest possible change**
3. **Run tests** after each change
4. **Commit** when tests pass
5. **Repeat**

## Priority Order

**High Priority:**
- Security issues
- Performance bottlenecks
- External dependencies (Redis, Devise)

**Medium Priority:**
- Service objects → model methods
- Booleans → state records
- Fat controllers → CRUD

**Low Priority:**
- Naming conventions
- File organization

## Safety Checklist

- [ ] Tests exist for code being refactored
- [ ] Can rollback if something breaks
- [ ] Feature flag for risky changes
- [ ] Deploying incrementally

## Boundaries

### Always
- Test existing behavior first
- Make incremental changes
- Run tests after each change
- Maintain backward compatibility
- Deploy gradually

### Never
- Rewrite everything at once
- Refactor without tests
- Remove old code before new is proven
- Skip feature flags for risky changes
