# Concern Catalog

Complete catalog of concern types used in 37signals-style Rails applications.

## State record concerns

Toggle boolean-like state via `has_one` state records:

| Concern | State Record | Methods | Scopes |
|---|---|---|---|
| `Closeable` | `has_one :closure` | `close`, `reopen`, `closed?`, `open?` | `:open`, `:closed` |
| `Publishable` | `has_one :publication` | `publish`, `unpublish`, `published?` | `:published`, `:private` |
| `Golden` | `has_one :goldness` | `gild`, `ungild`, `golden?` | `:golden`, `:not_golden` |
| `NotNowable` | `has_one :not_now` | `postpone`, `resume`, `postponed?` | `:postponed`, `:active` |
| `Archivable` | `has_one :archival` | `archive`, `unarchive`, `archived?` | `:archived`, `:active` |
| `Pinnable` | `has_one :pin` | `pin`, `unpin`, `pinned?` | `:pinned`, `:unpinned` |

### Template for state concerns:

```ruby
# app/models/card/closeable.rb
module Card::Closeable
  extend ActiveSupport::Concern

  included do
    has_one :closure, dependent: :destroy

    scope :open, -> { where.missing(:closure) }
    scope :closed, -> { joins(:closure) }
  end

  def close(user: Current.user)
    create_closure!(user: user)
    track_event "card_closed", user: user
  end

  def reopen
    closure&.destroy!
    track_event "card_reopened"
  end

  def closed?
    closure.present?
  end

  def open?
    !closed?
  end

  def closed_at
    closure&.created_at
  end

  def closed_by
    closure&.user
  end
end
```

## Association concerns

Manage related records through joins:

| Concern | Association | Methods | Scopes |
|---|---|---|---|
| `Assignable` | `has_many :assignments` | `assign`, `unassign`, `assigned_to?` | `:assigned_to`, `:unassigned` |
| `Watchable` | `has_many :watches` | `watch`, `unwatch`, `watched_by?` | `:watched_by`, `:unwatched` |
| `Commentable` | `has_many :comments` | (standard CRUD) | `:commented`, `:uncommented` |
| `Attachments` | `has_many :attachments` | (standard CRUD) | -- |

### Template for association concerns:

```ruby
# app/models/card/assignable.rb
module Card::Assignable
  extend ActiveSupport::Concern

  included do
    has_many :assignments, dependent: :destroy
    has_many :assignees, through: :assignments, source: :user

    scope :assigned_to, ->(user) { joins(:assignments).where(assignments: { user: user }) }
    scope :unassigned, -> { where.missing(:assignments) }
  end

  def assign(user)
    assignments.create!(user: user) unless assigned_to?(user)
  end

  def unassign(user)
    assignments.where(user: user).destroy_all
  end

  def assigned_to?(user)
    assignees.include?(user)
  end
end
```

## Behavior concerns

Add capabilities without associations:

| Concern | Purpose | Key Methods |
|---|---|---|
| `Searchable` | Full-text search scopes | `search`, `search_with_ranking` |
| `Positionable` | Ordering/positioning | `move_to_position`, scoped ordering |
| `Eventable` | Event tracking | `track_event`, `track_event_later` |
| `Broadcastable` | Turbo Stream broadcasting | `broadcast_update_later`, `broadcast_update_now` |
| `Readable` | Read tracking per user | `mark_as_read`, `unread_for?` |
| `Colorable` | Color attribute | `color`, `color=` |

### Template for event tracking:

```ruby
# app/models/card/eventable.rb
module Card::Eventable
  include ::Eventable

  PERMITTED_ACTIONS = %w[
    card_created card_closed card_reopened
    card_assigned card_unassigned
    card_gilded card_ungilded
    title_changed body_changed
  ]

  def track_title_change(old_title)
    track_event "title_changed", particulars: {
      old_title: old_title,
      new_title: title
    }
  end

  def track_body_change
    track_event "body_changed" if saved_change_to_body?
  end
end
```

## Controller concerns

### Resource scoping concerns

| Concern | Purpose | Provides |
|---|---|---|
| `CardScoped` | Load card from params | `@card`, `@board`, `render_card_replacement` |
| `BoardScoped` | Load board from params | `@board` |
| `ProjectScoped` | Load project from params | `@project` |

### Request context concerns

| Concern | Purpose | Example |
|---|---|---|
| `CurrentRequest` | Set Current attributes | `Current.user`, `Current.account`, `Current.session` |
| `CurrentTimezone` | Handle timezone | `around_action :set_time_zone` |
| `FilterScoped` | Handle filtering | `@filter`, `filtered?` helper |
| `Authentication` | Handle auth | Login/logout logic |

### Template for request context:

```ruby
# app/controllers/concerns/current_request.rb
module CurrentRequest
  extend ActiveSupport::Concern

  included do
    before_action :set_current_request_details
  end

  private

  def set_current_request_details
    Current.user = current_user
    Current.identity = current_identity
    Current.session = current_session
    Current.account = current_account
  end
end
```

### Template for timezone:

```ruby
# app/controllers/concerns/current_timezone.rb
module CurrentTimezone
  extend ActiveSupport::Concern

  included do
    around_action :set_time_zone
    etag { Current.identity&.timezone }
    helper_method :browser_timezone
  end

  private

  def set_time_zone(&block)
    Time.use_zone(browser_timezone, &block)
  end

  def browser_timezone
    cookies[:timezone].presence || "UTC"
  end
end
```
