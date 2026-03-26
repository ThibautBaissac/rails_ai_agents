# Refactoring Patterns

## Pattern 1: Service Object to Model Method

### Before (anti-pattern)
```ruby
class ProjectCreationService
  def initialize(user, params)
    @user = user
    @params = params
  end

  def call
    project = Project.create!(@params)
    project.add_member(@user, role: :owner)
    project.create_default_boards
    ProjectMailer.created(project).deliver_later
    project
  end
end
```

### After (37signals pattern)
```ruby
class Project < ApplicationRecord
  def self.create_with_defaults(creator:, **attributes)
    transaction do
      project = create!(attributes.merge(creator: creator))
      project.add_member(creator, role: :owner)
      project.create_default_boards
      project
    end
  end

  after_create_commit :send_creation_email

  private
    def send_creation_email
      ProjectMailer.created(self).deliver_later
    end
end
```

### Steps
1. Add tests for existing service behavior
2. Create model method with same logic
3. Update controller to call model method
4. Update tests to reference model method
5. Delete service object file
6. Run full test suite

## Pattern 2: Boolean Flag to State Record

### Before (anti-pattern)
```ruby
class Project < ApplicationRecord
  # Schema: approved boolean, approved_at datetime, approved_by_id integer
  scope :approved, -> { where(approved: true) }

  def approve!(user)
    update!(approved: true, approved_at: Time.current, approved_by: user)
  end
end
```

### After (37signals pattern)
```ruby
class Project < ApplicationRecord
  has_one :approval, dependent: :destroy

  scope :approved, -> { joins(:approval) }
  scope :unapproved, -> { where.missing(:approval) }

  def approved?
    approval.present?
  end
end

class Approval < ApplicationRecord
  belongs_to :project, touch: true
  belongs_to :approver, class_name: "User"
  belongs_to :account, default: -> { project.account }
end

# Controller
class Projects::ApprovalsController < ApplicationController
  def create
    @project = Current.account.projects.find(params[:project_id])
    @project.create_approval!(approver: Current.user)
    redirect_to @project
  end

  def destroy
    @project = Current.account.projects.find(params[:project_id])
    @project.approval.destroy!
    redirect_to @project
  end
end
```

### Steps
1. Create approvals table migration (project_id, approver_id, account_id)
2. Create Approval model with associations
3. Backfill: create Approval records from existing approved=true rows
4. Update Project model to use has_one :approval
5. Create ApprovalsController with create/destroy
6. Update tests
7. Remove boolean columns in a later deploy

## Pattern 3: God Controller to CRUD Resources

### Before (anti-pattern)
```ruby
class ProjectsController < ApplicationController
  def index; end
  def show; end
  def create; end
  def update; end
  def destroy; end
  def archive; end       # Custom action
  def publish; end       # Custom action
  def approve; end       # Custom action
  def assign; end        # Custom action
end
```

### After (37signals pattern)
```ruby
# app/controllers/projects_controller.rb
class ProjectsController < ApplicationController
  def index; end
  def show; end
  def create; end
  def update; end
  def destroy; end
end

# app/controllers/projects/archivals_controller.rb
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

# Similarly: Projects::PublicationsController, Projects::ApprovalsController
```

### Steps
1. Create state record model + migration for each custom action
2. Create nested controller for each
3. Move logic from custom action to new controller
4. Update routes to nested resources
5. Update views to point to new routes
6. Remove custom actions from original controller
7. Update tests

## Pattern 4: Callback Chain to Explicit Call

### Before (anti-pattern)
```ruby
class Card < ApplicationRecord
  after_save :update_board_count
  after_save :notify_watchers
  after_save :sync_to_search_index
  after_save :track_activity
  after_save :broadcast_update

  # 5 callbacks fire on every save, even for trivial updates
end
```

### After (37signals pattern)
```ruby
class Card < ApplicationRecord
  # Only data normalization callbacks
  before_validation :normalize_title

  # Notification callbacks use after_create_commit / after_update_commit
  after_create_commit :broadcast_creation
  after_update_commit :broadcast_update

  # Other side effects are explicit model methods
  def move_to(column)
    update!(column: column)
    track_activity(:moved)
    notify_watchers_later
  end

  def notify_watchers_later
    Card::NotifyWatchersJob.perform_later(self)
  end
end
```

### Steps
1. Audit all callbacks on the model
2. Keep before_validation for data normalization
3. Convert after_save to after_create_commit / after_update_commit
4. Move complex side effects into explicit methods
5. Use _later pattern for async operations
6. Update callers to use explicit methods

## Pattern 5: Concern Extraction from Fat Model

### Before (anti-pattern)
```ruby
class Card < ApplicationRecord
  # 500 lines mixing: closeable, assignable, searchable, taggable...
  has_one :closure
  scope :open, -> { where.missing(:closure) }
  def close!(user); create_closure!(user: user); end
  def closed?; closure.present?; end
  # ... 400 more lines
end

class Project < ApplicationRecord
  # Same closeable code duplicated
  has_one :closure
  scope :open, -> { where.missing(:closure) }
  def close!(user); create_closure!(user: user); end
  def closed?; closure.present?; end
end
```

### After (37signals pattern)
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

  def reopen!
    closure&.destroy!
  end

  def closed?
    closure.present?
  end
end

# app/models/card.rb
class Card < ApplicationRecord
  include Closeable
  include Assignable
  include Searchable
  # Only card-specific logic remains (~100 lines)
end
```

### Steps
1. Identify duplicate code across models
2. Create concern file in app/models/concerns/
3. Move shared associations, scopes, methods to concern
4. Include concern in first model, run tests
5. Include in second model, remove duplicate code, run tests
6. Add concern-specific tests
