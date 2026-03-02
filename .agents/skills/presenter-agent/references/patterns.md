# Presenter Patterns

## ApplicationPresenter Base Class

```ruby
# app/presenters/application_presenter.rb
class ApplicationPresenter < SimpleDelegator
  include ActionView::Helpers::TagHelper
  include ActionView::Helpers::NumberHelper
  include ActionView::Helpers::DateHelper
  include ActionView::Helpers::UrlHelper
  include Rails.application.routes.url_helpers

  attr_reader :object

  def initialize(object, view_context = nil)
    @object = object
    @view_context = view_context
    super(object)
  end

  def h
    @view_context
  end

  # Helper to create presenter instances
  def self.present(object, view_context = nil)
    return nil if object.nil?
    return object.map { |item| new(item, view_context) } if object.respond_to?(:map)

    new(object, view_context)
  end
end
```

## Basic Presenter Structure

```ruby
# app/presenters/entity_presenter.rb
class EntityPresenter < ApplicationPresenter
  # Delegate to the wrapped model
  delegate :id, :name, :status, :created_at, to: :object

  # Formatting methods
  def formatted_name
    name.titleize
  end

  def formatted_created_at
    created_at.strftime("%B %d, %Y at %I:%M %p")
  end

  def short_date
    created_at.strftime("%m/%d/%Y")
  end

  # Display logic
  def status_badge
    case status
    when 'published'
      h.content_tag(:span, 'Published', class: 'badge badge-success')
    when 'draft'
      h.content_tag(:span, 'Draft', class: 'badge badge-warning')
    when 'archived'
      h.content_tag(:span, 'Archived', class: 'badge badge-secondary')
    end
  end

  def status_class
    case status
    when 'published' then 'text-green-600'
    when 'draft' then 'text-yellow-600'
    when 'archived' then 'text-gray-600'
    else 'text-gray-400'
    end
  end

  # Conditional display
  def display_description
    description.presence || 'No description provided'
  end

  def can_be_edited?
    status == 'draft'
  end

  # Links
  def edit_link
    return nil unless can_be_edited?

    h.link_to 'Edit', h.edit_entity_path(object), class: 'btn btn-primary'
  end

  def delete_link
    return nil unless can_be_edited?

    h.link_to 'Delete',
              h.entity_path(object),
              method: :delete,
              data: { confirm: 'Are you sure?' },
              class: 'btn btn-danger'
  end
end
```

## User Presenter

```ruby
# app/presenters/user_presenter.rb
class UserPresenter < ApplicationPresenter
  delegate :id, :email, :first_name, :last_name, :created_at, to: :object

  # Display name with fallback
  def display_name
    full_name.presence || email.split('@').first
  end

  def full_name
    "#{first_name} #{last_name}".strip
  end

  def initials
    parts = [first_name, last_name].compact
    return email[0].upcase if parts.empty?

    parts.map { |part| part[0].upcase }.join
  end

  # Avatar
  def avatar_url(size: 80)
    gravatar_hash = Digest::MD5.hexdigest(email.downcase)
    "https://www.gravatar.com/avatar/#{gravatar_hash}?s=#{size}&d=identicon"
  end

  def avatar_tag(size: 80, css_class: 'avatar')
    h.image_tag(avatar_url(size: size), alt: display_name, class: css_class)
  end

  # Formatting
  def member_since
    "Member since #{created_at.strftime('%B %Y')}"
  end

  def joined_recently?
    created_at > 30.days.ago
  end

  # Links
  def profile_link(css_class: nil)
    h.link_to display_name, h.user_path(object), class: css_class
  end
end
```

## Post Presenter with Rich Formatting

```ruby
# app/presenters/post_presenter.rb
class PostPresenter < ApplicationPresenter
  delegate :id, :title, :body, :status, :published_at, :author, to: :object

  # Formatting
  def formatted_title
    title.titleize
  end

  def truncated_body(length: 200)
    return body if body.length <= length

    "#{body.truncate(length, separator: ' ')}..."
  end

  def reading_time
    words = body.split.size
    minutes = (words / 200.0).ceil
    "#{minutes} min read"
  end

  # Dates
  def published_date
    return 'Not published' unless published_at

    if published_at > 7.days.ago
      "#{time_ago_in_words(published_at)} ago"
    else
      published_at.strftime("%B %d, %Y")
    end
  end

  # Status
  def status_badge
    case status
    when 'published'
      h.content_tag(:span, 'Published', class: 'badge bg-success')
    when 'draft'
      h.content_tag(:span, 'Draft', class: 'badge bg-warning')
    else
      h.content_tag(:span, status.humanize, class: 'badge bg-secondary')
    end
  end

  # Author info
  def author_name
    author.present? ? author.full_name : 'Anonymous'
  end

  def byline
    "by #{author_name} on #{published_date}"
  end

  # Links
  def share_url
    h.url_for([object, host: h.request.host])
  end

  def twitter_share_link
    text = "Check out: #{formatted_title}"
    "https://twitter.com/intent/tweet?text=#{CGI.escape(text)}&url=#{CGI.escape(share_url)}"
  end
end
```

## Collection Presenter

```ruby
# app/presenters/entity_collection_presenter.rb
class EntityCollectionPresenter
  include ActionView::Helpers::TagHelper

  attr_reader :entities, :view_context

  def initialize(entities, view_context = nil)
    @entities = entities
    @view_context = view_context
  end

  def h
    @view_context
  end

  # Collection stats
  def total_count
    entities.size
  end

  def published_count
    entities.count { |e| e.status == 'published' }
  end

  def draft_count
    entities.count { |e| e.status == 'draft' }
  end

  # Formatting
  def summary
    "#{total_count} entities (#{published_count} published, #{draft_count} drafts)"
  end

  # Grouped display
  def by_status
    entities.group_by(&:status)
  end

  def presented_entities
    entities.map { |entity| EntityPresenter.new(entity, view_context) }
  end

  # Empty state
  def empty?
    entities.empty?
  end

  def empty_message
    content_tag(:p, "No entities found", class: "text-gray-500 text-center py-8")
  end
end
```

## Order Presenter with Number Formatting

```ruby
# app/presenters/order_presenter.rb
class OrderPresenter < ApplicationPresenter
  delegate :id, :status, :total, :created_at, :items_count, to: :object

  # Currency formatting
  def formatted_total
    number_to_currency(total, precision: 2)
  end

  def formatted_subtotal
    number_to_currency(subtotal, precision: 2)
  end

  def formatted_tax
    number_to_currency(tax_amount, precision: 2)
  end

  # Number formatting
  def items_text
    "#{items_count} #{items_count == 1 ? 'item' : 'items'}"
  end

  # Status
  def status_text
    status.humanize
  end

  def status_color
    {
      'pending' => 'yellow',
      'paid' => 'green',
      'shipped' => 'blue',
      'delivered' => 'green',
      'cancelled' => 'red'
    }[status] || 'gray'
  end

  def status_badge
    h.content_tag(:span, status_text, class: "badge bg-#{status_color}-500")
  end

  # Dates
  def order_date
    created_at.strftime("%B %d, %Y")
  end

  def estimated_delivery
    return nil unless status.in?(%w[paid shipped])

    delivery_date = created_at + 5.business_days
    delivery_date.strftime("%B %d, %Y")
  end
end
```

## Booking Presenter with Conditional Logic

```ruby
# app/presenters/booking_presenter.rb
class BookingPresenter < ApplicationPresenter
  delegate :id, :start_date, :end_date, :status, :user, to: :object

  # Status checks
  def active?
    status == 'confirmed' && end_date >= Date.today
  end

  def past?
    end_date < Date.today
  end

  def upcoming?
    active? && start_date > Date.today
  end

  def in_progress?
    active? && start_date <= Date.today && end_date >= Date.today
  end

  # Display logic
  def status_text
    return 'Cancelled' if status == 'cancelled'
    return 'Completed' if past?
    return 'In Progress' if in_progress?
    return 'Upcoming' if upcoming?

    status.humanize
  end

  def status_class
    return 'text-red-600' if status == 'cancelled'
    return 'text-gray-600' if past?
    return 'text-green-600' if in_progress?
    return 'text-blue-600' if upcoming?

    'text-gray-400'
  end

  # Date formatting
  def formatted_dates
    "#{start_date.strftime('%b %d')} - #{end_date.strftime('%b %d, %Y')}"
  end

  def duration_in_days
    (end_date - start_date).to_i + 1
  end

  def duration_text
    days = duration_in_days
    "#{days} #{days == 1 ? 'day' : 'days'}"
  end

  # Actions
  def can_cancel?
    active? && start_date > 1.day.from_now
  end

  def cancel_button
    return nil unless can_cancel?

    h.button_to 'Cancel Booking',
                h.cancel_booking_path(object),
                method: :post,
                data: { confirm: 'Are you sure?' },
                class: 'btn btn-danger'
  end
end
```

## Usage in Views

### Basic Usage

```erb
<%# app/views/entities/show.html.erb %>
<% presenter = EntityPresenter.new(@entity, self) %>

<div class="entity-card">
  <h1><%= presenter.formatted_name %></h1>

  <div class="metadata">
    <%= presenter.status_badge %>
    <span class="date"><%= presenter.formatted_created_at %></span>
  </div>

  <p><%= presenter.display_description %></p>

  <div class="actions">
    <%= presenter.edit_link %>
    <%= presenter.delete_link %>
  </div>
</div>
```

### Using Helper Method

```ruby
# app/helpers/application_helper.rb
module ApplicationHelper
  def present(object, klass = nil)
    klass ||= "#{object.class}Presenter".constantize
    klass.new(object, self)
  end
end
```

```erb
<%# app/views/entities/show.html.erb %>
<% entity = present(@entity) %>

<h1><%= entity.formatted_name %></h1>
<%= entity.status_badge %>
```

### Collection Usage

```erb
<%# app/views/entities/index.html.erb %>
<% entities = @entities.map { |e| EntityPresenter.new(e, self) } %>

<% entities.each do |entity| %>
  <div class="entity-item">
    <h3><%= entity.formatted_name %></h3>
    <%= entity.status_badge %>
  </div>
<% end %>
```
