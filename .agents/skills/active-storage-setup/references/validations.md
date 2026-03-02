# Active Storage: Validations

## Using the active_storage_validations Gem

```ruby
# Gemfile
gem 'active_storage_validations'
```

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_one_attached :avatar

  validates :avatar,
    content_type: ['image/png', 'image/jpeg', 'image/webp'],
    size: { less_than: 5.megabytes }
end

# app/models/event.rb
class Event < ApplicationRecord
  has_many_attached :documents

  validates :documents,
    content_type: ['application/pdf', 'image/png', 'image/jpeg'],
    size: { less_than: 10.megabytes },
    limit: { max: 10 }
end
```

## Manual Validation

```ruby
class User < ApplicationRecord
  has_one_attached :avatar

  validate :acceptable_avatar

  private

  def acceptable_avatar
    return unless avatar.attached?

    unless avatar.blob.byte_size <= 5.megabytes
      errors.add(:avatar, "is too large (max 5MB)")
    end

    acceptable_types = ["image/jpeg", "image/png", "image/webp"]
    unless acceptable_types.include?(avatar.content_type)
      errors.add(:avatar, "must be a JPEG, PNG, or WebP")
    end
  end
end
```
