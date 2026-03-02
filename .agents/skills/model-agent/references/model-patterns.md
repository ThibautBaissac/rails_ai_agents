# Common ActiveRecord Model Patterns

## Model Structure Template

```ruby
class Resource < ApplicationRecord
  # Constants
  STATUSES = %w[draft published archived].freeze

  # Associations (order: belongs_to, has_one, has_many, has_and_belongs_to_many)
  belongs_to :user
  has_many :comments, dependent: :destroy

  # Validations (order: presence, format, length, numericality, inclusion, custom)
  validates :name, presence: true, length: { minimum: 2, maximum: 100 }
  validates :status, inclusion: { in: STATUSES }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true

  # Callbacks (use sparingly!)
  before_validation :normalize_data

  # Scopes
  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }

  # Rails 7.1+ Token generation (for password resets, etc.)
  # generates_token_for :password_reset, expires_in: 15.minutes

  # Class methods
  def self.search(query)
    where("name ILIKE ?", "%#{sanitize_sql_like(query)}%")
  end

  # Instance methods (simple query methods only)
  def published?
    status == 'published'
  end

  def owner?(user)
    self.user_id == user.id
  end

  private

  def normalize_data
    self.name = name.strip if name.present?
  end
end
```

## Pattern 1: Basic Model with Associations

```ruby
class Post < ApplicationRecord
  belongs_to :user
  belongs_to :category, optional: true
  has_many :comments, dependent: :destroy
  has_many :tags, through: :post_tags

  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :body, presence: true
  validates :status, inclusion: { in: %w[draft published] }

  scope :published, -> { where(status: 'published') }
  scope :recent, -> { order(created_at: :desc) }

  def published?
    status == 'published'
  end
end
```

## Pattern 2: Model with Enums

```ruby
class Order < ApplicationRecord
  belongs_to :user
  has_many :line_items, dependent: :destroy

  # Rails 7+ enum syntax with prefix/suffix
  enum :status, {
    pending: "pending",
    paid: "paid",
    shipped: "shipped",
    delivered: "delivered",
    cancelled: "cancelled"
  }, prefix: true, validate: true

  validates :status, presence: true
  validates :total, numericality: { greater_than: 0 }

  scope :active, -> { where.not(status: 'cancelled') }
  scope :recent, -> { order(created_at: :desc) }
end
```

## Pattern 3: Model with Polymorphic Association

```ruby
class Comment < ApplicationRecord
  belongs_to :commentable, polymorphic: true
  belongs_to :user

  validates :body, presence: true, length: { minimum: 1, maximum: 1000 }

  scope :recent, -> { order(created_at: :desc) }
  scope :for_posts, -> { where(commentable_type: 'Post') }
  scope :for_articles, -> { where(commentable_type: 'Article') }
end
```

## Pattern 4: Model with Custom Validations

```ruby
class Booking < ApplicationRecord
  belongs_to :user
  belongs_to :resource

  validates :start_date, presence: true
  validates :end_date, presence: true
  validate :end_date_after_start_date
  validate :no_overlapping_bookings

  scope :active, -> { where('end_date >= ?', Time.current) }
  scope :past, -> { where('end_date < ?', Time.current) }

  private

  def end_date_after_start_date
    return if end_date.blank? || start_date.blank?

    if end_date <= start_date
      errors.add(:end_date, "must be after start date")
    end
  end

  def no_overlapping_bookings
    return if start_date.blank? || end_date.blank?

    overlapping = resource.bookings
      .where.not(id: id)
      .where("start_date < ? AND end_date > ?", end_date, start_date)

    if overlapping.exists?
      errors.add(:base, "dates overlap with existing booking")
    end
  end
end
```

## Pattern 5: Model with Scopes and Query Methods

```ruby
class Article < ApplicationRecord
  belongs_to :author, class_name: 'User'
  has_many :comments, as: :commentable, dependent: :destroy

  validates :title, presence: true, length: { minimum: 5, maximum: 200 }
  validates :slug, presence: true, uniqueness: true
  validates :status, inclusion: { in: %w[draft published archived] }

  scope :published, -> { where(status: 'published') }
  scope :draft, -> { where(status: 'draft') }
  scope :recent, -> { order(published_at: :desc) }
  scope :by_author, ->(author) { where(author: author) }
  scope :search, ->(query) { where("title ILIKE ?", "%#{sanitize_sql_like(query)}%") }

  def self.published_this_month
    published.where(published_at: Time.current.beginning_of_month..Time.current.end_of_month)
  end

  def published?
    status == 'published' && published_at.present?
  end

  def can_be_edited_by?(user)
    author == user || user.admin?
  end
end
```

## Pattern 6: Model with Callbacks (Use Sparingly!)

```ruby
class User < ApplicationRecord
  has_many :posts, dependent: :destroy

  validates :email, presence: true, uniqueness: true
  validates :username, presence: true, uniqueness: true

  # Callbacks - use sparingly!
  before_validation :normalize_email
  before_create :generate_username, if: -> { username.blank? }
  after_create :send_welcome_email

  # Rails 7.1+ normalizes (preferred over callbacks)
  # normalizes :email, with: ->(email) { email.strip.downcase }

  private

  def normalize_email
    self.email = email.downcase.strip if email.present?
  end

  def generate_username
    self.username = email.split('@').first
  end

  def send_welcome_email
    # Use ActiveJob for background processing
    UserMailer.welcome(self).deliver_later
  end
end
```

## Pattern 7: Model with Delegations

```ruby
class Profile < ApplicationRecord
  belongs_to :user

  validates :bio, length: { maximum: 500 }
  validates :location, length: { maximum: 100 }

  delegate :email, :username, to: :user
  delegate :admin?, to: :user, prefix: true

  def full_name
    "#{first_name} #{last_name}".strip.presence || username
  end
end
```

## Pattern 8: Model with JSON/JSONB Attributes

```ruby
class Settings < ApplicationRecord
  belongs_to :user

  # PostgreSQL JSONB column
  store_accessor :preferences, :theme, :language, :notifications

  validates :theme, inclusion: { in: %w[light dark], allow_nil: true }
  validates :language, inclusion: { in: %w[en fr es], allow_nil: true }

  after_initialize :set_defaults, if: :new_record?

  private

  def set_defaults
    self.preferences ||= {}
    self.preferences['theme'] ||= 'light'
    self.preferences['language'] ||= 'en'
    self.preferences['notifications'] ||= true
  end
end
```
