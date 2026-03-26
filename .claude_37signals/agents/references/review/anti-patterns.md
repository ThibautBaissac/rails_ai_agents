# Anti-Patterns Catalog

## 1. Custom Controller Actions

### Bad
```ruby
class ProjectsController < ApplicationController
  def archive
    @project.update(archived: true)
    redirect_to @project
  end

  def unarchive
    @project.update(archived: false)
    redirect_to @project
  end

  def approve
    @project.update(approved: true, approved_by: Current.user)
    redirect_to @project
  end
end
```

### Good
```ruby
# Each state change is a separate CRUD resource
class Projects::ArchivalsController < ApplicationController
  def create
    @project = Current.account.projects.find(params[:project_id])
    @project.create_archival!(user: Current.user)
    redirect_to @project
  end

  def destroy
    @project = Current.account.projects.find(params[:project_id])
    @project.archival.destroy!
    redirect_to @project
  end
end
```

**Why:** Each state change deserves its own model, controller, and URL. This gives you auditing (who archived it, when), clean routes, and focused controllers.

---

## 2. Service Objects

### Bad
```ruby
class ProjectCreationService
  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    project = Project.new(@params)
    project.creator = @user
    project.save!
    NotificationMailer.project_created(project).deliver_later
    project
  end
end
```

### Good
```ruby
class Project < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }

  after_create_commit :notify_team

  private
    def notify_team
      NotificationMailer.project_created(self).deliver_later
    end
end
```

**Why:** The model knows its own domain. Default values handle context. Callbacks handle side effects. No indirection layer needed.

---

## 3. Boolean Flags for State

### Bad
```ruby
class Card < ApplicationRecord
  # Schema: closed boolean, closed_at datetime, closed_by_id integer
  scope :open, -> { where(closed: false) }
  scope :closed, -> { where(closed: true) }

  def close!(user)
    update!(closed: true, closed_at: Time.current, closed_by_id: user.id)
  end
end
```

### Good
```ruby
class Card < ApplicationRecord
  has_one :closure, dependent: :destroy

  scope :open, -> { where.missing(:closure) }
  scope :closed, -> { joins(:closure) }

  def close!(user)
    create_closure!(user: user)
  end

  def closed?
    closure.present?
  end
end

class Closure < ApplicationRecord
  belongs_to :card, touch: true
  belongs_to :user
  belongs_to :account, default: -> { card.account }
end
```

**Why:** State records give you free timestamps, who-did-it tracking, and clean queries. No need for three columns when one record does it all.

---

## 4. Fat Controllers

### Bad
```ruby
class CommentsController < ApplicationController
  def create
    @comment = @card.comments.build(comment_params)
    @comment.creator = Current.user
    @comment.account = Current.account

    if @comment.body.match?(/@\w+/)
      mentions = @comment.body.scan(/@(\w+)/).flatten
      users = User.where(username: mentions)
      users.each do |user|
        NotificationMailer.mentioned(user, @comment).deliver_later
      end
    end

    @comment.save!
    redirect_to @card
  end
end
```

### Good
```ruby
class CommentsController < ApplicationController
  def create
    @comment = @card.comments.create!(comment_params)
    redirect_to @card
  end
end

class Comment < ApplicationRecord
  belongs_to :creator, class_name: "User", default: -> { Current.user }
  belongs_to :account, default: -> { card.account }

  after_create_commit :notify_mentions

  def mentioned_users
    usernames = body.scan(/@(\w+)/).flatten
    account.users.where(username: usernames)
  end

  private
    def notify_mentions
      mentioned_users.each do |user|
        NotificationMailer.mentioned(user, self).deliver_later
      end
    end
end
```

**Why:** Controller should be three lines: find, act, respond. Business logic (mention parsing, notifications) belongs in the model.

---

## 5. Missing Account Scoping

### Bad
```ruby
class ProjectsController < ApplicationController
  def index
    @projects = Project.all
  end

  def show
    @project = Project.find(params[:id])
  end
end
```

### Good
```ruby
class ProjectsController < ApplicationController
  def index
    @projects = Current.account.projects
  end

  def show
    @project = Current.account.projects.find(params[:id])
  end
end
```

**Why:** Without account scoping, users can see (and modify) other accounts' data. This is a security vulnerability in any multi-tenant application.

---

## 6. Duplicate Model Code (Missing Concerns)

### Bad
```ruby
class Card < ApplicationRecord
  has_one :closure, dependent: :destroy
  scope :open, -> { where.missing(:closure) }
  def close!(user); create_closure!(user: user); end
  def closed?; closure.present?; end
end

class Project < ApplicationRecord
  has_one :closure, dependent: :destroy
  scope :open, -> { where.missing(:closure) }
  def close!(user); create_closure!(user: user); end
  def closed?; closure.present?; end
end
```

### Good
```ruby
# app/models/concerns/closeable.rb
module Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, as: :closeable, dependent: :destroy
    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
  end

  def close!(user = nil)
    create_closure!(user: user || Current.user)
  end

  def closed?
    closure.present?
  end
end

class Card < ApplicationRecord
  include Closeable
end

class Project < ApplicationRecord
  include Closeable
end
```

**Why:** DRY. One place to maintain. Easy to add closeable behavior to new models.

---

## 7. RSpec + FactoryBot

### Bad
```ruby
RSpec.describe Project do
  let(:account) { create(:account) }
  let(:user) { create(:user, account: account) }
  let(:project) { create(:project, account: account, creator: user) }

  it "archives project" do
    project.archive!
    expect(project.archived?).to be true
  end
end
```

### Good
```ruby
class ProjectTest < ActiveSupport::TestCase
  test "archives project" do
    project = projects(:active_project)
    project.archive!
    assert project.archived?
  end
end

# test/fixtures/projects.yml
active_project:
  account: fizzy
  name: "Q4 Planning"
  creator: alice (User)
```

**Why:** Fixtures load once, are shared across all tests, and are faster. No factory definition complexity. Test data is visible in YAML files.

---

## 8. Blocking Operations in Request Cycle

### Bad
```ruby
class ReportsController < ApplicationController
  def create
    @report = Report.create!(report_params)
    @report.generate_data!    # Takes 30 seconds
    redirect_to @report
  end
end
```

### Good
```ruby
class ReportsController < ApplicationController
  def create
    @report = Report.create!(report_params)
    @report.generate_later
    redirect_to @report, notice: "Report is being generated..."
  end
end

class Report < ApplicationRecord
  def generate_later
    Report::GenerateJob.perform_later(self)
  end

  def generate_now
    Report::GenerateJob.perform_now(self)
  end
end

class Report::GenerateJob < ApplicationJob
  def perform(report)
    report.generate_data!
  end
end
```

**Why:** Users should not wait for slow operations. Background jobs return instantly and process async. The `_later/_now` pattern gives you both async and sync options.

---

## 9. deliver_now in Controllers

### Bad
```ruby
class ArchivalsController < ApplicationController
  def create
    @archival = @project.create_archival!(user: Current.user)
    ArchivalMailer.archived(@project).deliver_now  # Blocks request
    redirect_to @project
  end
end
```

### Good
```ruby
class Archival < ApplicationRecord
  after_create_commit :send_notification

  private
    def send_notification
      ArchivalMailer.archived(project).deliver_later
    end
end
```

**Why:** Email delivery should never block a request. Use `deliver_later` in an `after_create_commit` callback so the email sends after the transaction commits, in a background job.

---

## 10. Missing HTTP Caching

### Bad
```ruby
class ProjectsController < ApplicationController
  def show
    @project = Current.account.projects.find(params[:id])
  end
end
```

### Good
```ruby
class ProjectsController < ApplicationController
  def show
    @project = Current.account.projects.find(params[:id])
    fresh_when @project
  end
end
```

**Why:** One line gives you automatic 304 Not Modified responses. Combined with `touch: true` on associations, cache invalidation is automatic.

---

## Quick Reference Table

| Anti-Pattern | 37signals Pattern | Severity |
|---|---|---|
| Custom controller actions | New CRUD resource + state record | Critical |
| Service objects | Rich model methods | Critical |
| `Model.find(id)` without scoping | `Current.account.models.find(id)` | Critical |
| Boolean flags for state | State record (Closure, Archival) | High |
| Business logic in controller | Move to model | High |
| `deliver_now` in controller | `deliver_later` in `after_create_commit` | High |
| Slow operation in request | Background job with `_later` | High |
| Duplicate code across models | Extract concern | Medium |
| RSpec + FactoryBot | Minitest + fixtures | Medium |
| Sidekiq + Redis | Solid Queue | Medium |
| Missing `fresh_when` | Add HTTP caching | Low |
| Vague method names | Specific action verbs | Low |
