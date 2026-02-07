---
name: 37signals-implement
description: Orchestrate complete feature implementations by coordinating specialized patterns. Triggers on implement feature, build, full stack, end to end, coordinate, orchestrate.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Implement Skill

## Overview

Orchestrate complete Rails feature implementations by breaking down requirements and applying specialized patterns in the correct dependency order.

## Core Philosophy

- **Analyze first**: Break requirements into component tasks
- **Follow dependency order**: Database → Models → Controllers → Views → Jobs → Tests
- **Coordinate patterns**: Apply specialized patterns consistently
- **Ensure multi-tenancy**: Account scope throughout

## Implementation Order

```
1. Database (migration patterns)
   ↓
2. Models (rich domain logic, concerns)
   ↓
3. Controllers (CRUD, account scoping)
   ↓
4. Views (Turbo, Stimulus)
   ↓
5. Background Jobs (Solid Queue)
   ↓
6. Emails (mailer patterns)
   ↓
7. Events/Webhooks
   ↓
8. Caching
   ↓
9. API (JSON responses)
   ↓
10. Tests (throughout)
```

## Pattern Selection Guide

| Need | Pattern |
|------|---------|
| New resource | CRUD + Model + Migration |
| State toggle | State Records (Closure, Publication) |
| Shared behavior | Concerns |
| Real-time updates | Turbo Streams |
| Background work | Jobs with _later/_now |
| Notifications | Mailer with bundling |
| Tracking | Events as domain models |
| Performance | Caching with ETags |
| API access | Same controller + Jbuilder |

## Workflow: New CRUD Resource

**Example: Add Projects to application**

### Step 1: Migration
```ruby
create_table :projects, id: :uuid do |t|
  t.references :account, null: false, type: :uuid
  t.references :creator, null: false, type: :uuid
  t.string :name, null: false
  t.text :description
  t.string :status, default: "active"
  t.timestamps
end
```

### Step 2: Model
```ruby
class Project < ApplicationRecord
  include AccountScoped
  include Closeable

  belongs_to :creator, class_name: "User", default: -> { Current.user }
  has_many :tasks, dependent: :destroy

  validates :name, presence: true
  scope :active, -> { where(status: "active") }
end
```

### Step 3: Controller
```ruby
class ProjectsController < ApplicationController
  def index
    @projects = Current.account.projects.includes(:creator).active
    fresh_when @projects
  end

  def create
    @project = Current.account.projects.build(project_params)
    @project.creator = Current.user

    respond_to do |format|
      if @project.save
        format.html { redirect_to @project }
        format.turbo_stream
        format.json { render :show, status: :created }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @project.errors, status: :unprocessable_entity }
      end
    end
  end
end
```

### Step 4: Views with Turbo
```erb
<%= turbo_frame_tag "projects" do %>
  <%= render @projects %>
<% end %>
```

### Step 5: Tests
```ruby
class ProjectTest < ActiveSupport::TestCase
  test "validates name presence" do
    project = Project.new(account: accounts(:acme))
    assert_not project.valid?
  end

  test "active scope excludes archived" do
    project = projects(:one)
    project.update!(status: "archived")
    assert_not_includes Project.active, project
  end
end
```

## Workflow: State Management

**Example: Track when projects are archived**

### Step 1: State Record Migration
```ruby
create_table :archivals, id: :uuid do |t|
  t.references :account, null: false, type: :uuid
  t.references :project, null: false, type: :uuid
  t.references :user, type: :uuid
  t.text :reason
  t.timestamps
end
add_index :archivals, :project_id, unique: true
```

### Step 2: Model with Concern
```ruby
# app/models/project/archivable.rb
module Project::Archivable
  extend ActiveSupport::Concern

  included do
    has_one :archival, dependent: :destroy
    scope :active, -> { where.missing(:archival) }
    scope :archived, -> { joins(:archival) }
  end

  def archive(user: Current.user, reason: nil)
    create_archival!(user: user, reason: reason, account: account)
  end

  def unarchive
    archival&.destroy!
  end

  def archived?
    archival.present?
  end
end
```

### Step 3: CRUD Controller
```ruby
class Projects::ArchivalsController < ApplicationController
  def create
    @project.archive(reason: params[:reason])
    redirect_to @project
  end

  def destroy
    @project.unarchive
    redirect_to @project
  end
end
```

## Workflow: Background Processing

**Example: Export data as CSV**

### Step 1: Model with _later/_now
```ruby
class Project < ApplicationRecord
  def export_csv_later
    ExportProjectJob.perform_later(self)
  end

  def export_csv_now
    CSV.generate do |csv|
      csv << ["Name", "Status", "Created"]
      tasks.each { |t| csv << [t.name, t.status, t.created_at] }
    end
  end
end
```

### Step 2: Thin Job
```ruby
class ExportProjectJob < ApplicationJob
  queue_as :exports

  def perform(project)
    csv = project.export_csv_now
    ExportMailer.ready(project, csv).deliver_now
  end
end
```

### Step 3: Controller
```ruby
class Projects::ExportsController < ApplicationController
  def create
    @project.export_csv_later
    redirect_to @project, notice: "Export started. You'll receive an email."
  end
end
```

## Multi-Tenant Consistency

For any feature:

1. **Migration**: Add `account_id` with index
2. **Model**: `belongs_to :account`, validate presence
3. **Controller**: Scope through `Current.account`
4. **Tests**: Verify cross-account isolation

```ruby
# Always scope queries
Current.account.projects.find(params[:id])

# Never trust params directly
Project.find(params[:id])  # ❌ Security risk
```

## Implementation Checklist

- [ ] Migration with UUIDs and account_id
- [ ] Model with validations and associations
- [ ] Concerns for shared behavior
- [ ] Controller with CRUD actions
- [ ] Views with Turbo Frames/Streams
- [ ] Background jobs for async work
- [ ] Mailer for notifications
- [ ] Events for tracking
- [ ] HTTP caching (ETags)
- [ ] JSON API support
- [ ] Model tests
- [ ] Controller tests
- [ ] System tests

## Boundaries

### Always
- Analyze requirements before implementing
- Follow dependency order
- Ensure multi-tenant scoping
- Include tests at each layer
- Use established patterns

### Never
- Skip the analysis phase
- Ignore dependency order
- Forget account scoping
- Skip tests
