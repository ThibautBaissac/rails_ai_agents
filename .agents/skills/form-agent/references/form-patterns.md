# Form Object Patterns

## ApplicationForm Base Class

```ruby
# app/forms/application_form.rb
class ApplicationForm
  include ActiveModel::Model
  include ActiveModel::Attributes
  include ActiveModel::Validations

  def save
    return false unless valid?

    persist!
    true
  rescue ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  end

  private

  def persist!
    raise NotImplementedError, "Subclasses must implement #persist!"
  end
end
```

## Pattern 1: Simple Multi-Model Form

```ruby
# app/forms/entity_registration_form.rb
class EntityRegistrationForm < ApplicationForm
  attribute :name, :string
  attribute :description, :text
  attribute :address, :string
  attribute :phone, :string
  attribute :email, :string
  attribute :owner_id, :integer

  validates :name, presence: true, length: { minimum: 3, maximum: 100 }
  validates :description, presence: true, length: { minimum: 10 }
  validates :address, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :owner_id, presence: true

  validate :owner_exists

  attr_reader :entity

  private

  def persist!
    ActiveRecord::Base.transaction do
      @entity = create_entity
      create_contact_info
      notify_owner
    end
  end

  def create_entity
    Entity.create!(
      owner_id: owner_id,
      name: name,
      description: description,
      address: address
    )
  end

  def create_contact_info
    entity.create_contact_info!(
      phone: phone,
      email: email
    )
  end

  def notify_owner
    EntityMailer.registration_confirmation(entity).deliver_later
  end

  def owner_exists
    errors.add(:owner_id, "does not exist") unless User.exists?(owner_id)
  end
end
```

## Pattern 2: Form with Nested Associations

```ruby
# app/forms/entity_with_items_form.rb
class EntityWithItemsForm < ApplicationForm
  attribute :name, :string
  attribute :description, :text
  attribute :owner_id, :integer

  attribute :items, default: -> { [] }

  validates :name, presence: true
  validates :owner_id, presence: true
  validate :validate_items

  attr_reader :entity

  private

  def persist!
    ActiveRecord::Base.transaction do
      @entity = create_entity
      create_items
    end
  end

  def create_entity
    Entity.create!(
      owner_id: owner_id,
      name: name,
      description: description
    )
  end

  def create_items
    items.each do |item_attrs|
      next if item_attrs[:name].blank?

      entity.items.create!(
        name: item_attrs[:name],
        description: item_attrs[:description],
        price: item_attrs[:price],
        category: item_attrs[:category]
      )
    end
  end

  def validate_items
    return if items.blank?

    items.each_with_index do |item, index|
      next if item[:name].blank?

      if item[:price].to_f <= 0
        errors.add(:base, "Item #{index + 1} price must be positive")
      end
    end
  end
end
```

## Pattern 3: Form with Virtual Attributes and Calculations

```ruby
# app/forms/content_submission_form.rb
class ContentSubmissionForm < ApplicationForm
  attribute :entity_id, :integer
  attribute :author_id, :integer
  attribute :rating, :integer
  attribute :content, :text
  attribute :published_date, :date
  attribute :featured, :boolean, default: false

  attribute :quality_score, :integer
  attribute :accuracy_score, :integer
  attribute :relevance_score, :integer
  attribute :engagement_score, :integer

  validates :entity_id, :author_id, presence: true
  validates :rating, inclusion: { in: 1..5 }
  validates :content, presence: true, length: { minimum: 20, maximum: 1000 }
  validates :quality_score, :accuracy_score, :relevance_score, :engagement_score,
            inclusion: { in: 1..5 }, allow_nil: false

  validate :author_hasnt_submitted_already
  validate :published_date_not_in_future

  attr_reader :submission

  private

  def persist!
    ActiveRecord::Base.transaction do
      @submission = create_submission
      create_scores
      update_entity_rating
    end
  end

  def create_submission
    Submission.create!(
      entity_id: entity_id,
      author_id: author_id,
      rating: calculated_overall_rating,
      content: content,
      published_date: published_date,
      featured: featured
    )
  end

  def create_scores
    submission.create_score!(
      quality: quality_score,
      accuracy: accuracy_score,
      relevance: relevance_score,
      engagement: engagement_score
    )
  end

  def calculated_overall_rating
    ((quality_score * 0.4) + (accuracy_score * 0.3) +
     (relevance_score * 0.2) + (engagement_score * 0.1)).round
  end

  def update_entity_rating
    Entities::CalculateRatingService.call(
      entity: Entity.find(entity_id)
    )
  end

  def author_hasnt_submitted_already
    if Submission.exists?(author_id: author_id, entity_id: entity_id)
      errors.add(:base, "You have already submitted content for this entity")
    end
  end

  def published_date_not_in_future
    if published_date.present? && published_date > Date.current
      errors.add(:published_date, "cannot be in the future")
    end
  end
end
```

## Pattern 4: Edit Form with Pre-Population

```ruby
# app/forms/user_profile_form.rb
class UserProfileForm < ApplicationForm
  attribute :user_id, :integer
  attribute :first_name, :string
  attribute :last_name, :string
  attribute :email, :string
  attribute :bio, :text
  attribute :avatar # For file upload
  attribute :notification_preferences, default: -> { {} }

  validates :first_name, :last_name, :email, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  validate :email_uniqueness

  attr_reader :user

  def initialize(attributes = {})
    @user = User.find_by(id: attributes[:user_id])
    super(attributes.merge(user_attributes))
  end

  private

  def persist!
    user.update!(
      first_name: first_name,
      last_name: last_name,
      email: email,
      bio: bio
    )

    user.avatar.attach(avatar) if avatar.present?
    update_preferences
  end

  def update_preferences
    user.notification_preference&.update!(notification_preferences) ||
      user.create_notification_preference!(notification_preferences)
  end

  def user_attributes
    return {} unless user

    {
      first_name: user.first_name,
      last_name: user.last_name,
      email: user.email,
      bio: user.bio,
      notification_preferences: user.notification_preference&.attributes&.slice(
        "email_notifications", "email_mentions", "push_enabled"
      ) || {}
    }
  end

  def email_uniqueness
    existing = User.where(email: email).where.not(id: user_id).exists?
    errors.add(:email, "is already taken") if existing
  end
end
```
