---
name: active-storage-setup
description: Configures Active Storage for file uploads with variants and direct uploads. Use when adding file uploads, image attachments, document storage, generating thumbnails, or when user mentions Active Storage, file upload, attachments, or image processing.
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Active Storage Setup for Rails 8

## Overview

Active Storage handles file uploads in Rails:
- Cloud storage (S3, GCS, Azure) or local disk
- Image variants (thumbnails, resizing)
- Direct uploads from browser
- Polymorphic attachments

## Quick Start

```bash
# Install Active Storage (if not already)
bin/rails active_storage:install
bin/rails db:migrate

# Add image processing
bundle add image_processing
```

## Configuration

### Storage Services

```yaml
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

test:
  service: Disk
  root: <%= Rails.root.join("tmp/storage") %>

amazon:
  service: S3
  access_key_id: <%= Rails.application.credentials.dig(:aws, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:aws, :secret_access_key) %>
  region: eu-west-1
  bucket: <%= Rails.application.credentials.dig(:aws, :bucket) %>

google:
  service: GCS
  credentials: <%= Rails.root.join("config/gcs-credentials.json") %>
  project: my-project
  bucket: my-bucket
```

### Environment Config

```ruby
# config/environments/development.rb
config.active_storage.service = :local

# config/environments/production.rb
config.active_storage.service = :amazon
```

## Model Attachments

### Single Attachment

```ruby
# app/models/user.rb
class User < ApplicationRecord
  has_one_attached :avatar

  # With variant defaults
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
  end
end
```

### Multiple Attachments

```ruby
# app/models/event.rb
class Event < ApplicationRecord
  has_many_attached :photos

  has_many_attached :documents do |attachable|
    attachable.variant :preview, resize_to_limit: [200, 200]
  end
end
```

## TDD Workflow

```
Active Storage Progress:
- [ ] Step 1: Add attachment to model
- [ ] Step 2: Write model spec for attachment
- [ ] Step 3: Add validations (type, size)
- [ ] Step 4: Create upload form
- [ ] Step 5: Handle in controller
- [ ] Step 6: Display in views
- [ ] Step 7: Test upload flow
```

## Testing Attachments

### Model Spec

```ruby
# spec/models/user_spec.rb
require 'rails_helper'

RSpec.describe User, type: :model do
  describe "avatar attachment" do
    let(:user) { create(:user) }

    it "attaches an avatar" do
      user.avatar.attach(
        io: File.open(Rails.root.join("spec/factories/files/avatar.jpg")),
        filename: "avatar.jpg",
        content_type: "image/jpeg"
      )

      expect(user.avatar).to be_attached
    end

    it "generates variants" do
      user.avatar.attach(
        io: File.open(Rails.root.join("spec/factories/files/avatar.jpg")),
        filename: "avatar.jpg",
        content_type: "image/jpeg"
      )

      expect(user.avatar.variant(:thumb)).to be_present
    end
  end
end
```

### Factory with Attachments

```ruby
# spec/factories/users.rb
FactoryBot.define do
  factory :user do
    name { Faker::Name.name }

    trait :with_avatar do
      after(:build) do |user|
        user.avatar.attach(
          io: File.open(Rails.root.join("spec/factories/files/avatar.jpg")),
          filename: "avatar.jpg",
          content_type: "image/jpeg"
        )
      end
    end
  end
end

# Usage
create(:user, :with_avatar)
```

### Request Spec

```ruby
# spec/requests/users_spec.rb
RSpec.describe "Users", type: :request do
  describe "PATCH /users/:id" do
    let(:user) { create(:user) }
    let(:avatar) { fixture_file_upload("avatar.jpg", "image/jpeg") }

    before { sign_in user }

    it "uploads avatar" do
      patch user_path(user), params: { user: { avatar: avatar } }

      expect(user.reload.avatar).to be_attached
    end
  end
end
```

## Validations

### Using ActiveStorage Validations Gem

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

### Manual Validation

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

## Image Variants

### Defining Variants

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_fill: [100, 100]
    attachable.variant :medium, resize_to_limit: [300, 300]
    attachable.variant :large, resize_to_limit: [800, 800]
  end
end
```

### Variant Operations

```ruby
# Resize to fit within dimensions (maintains aspect ratio)
resize_to_limit: [300, 300]

# Resize and crop to exact dimensions
resize_to_fill: [300, 300]

# Resize to cover dimensions (may exceed)
resize_to_cover: [300, 300]

# Custom processing
resize_to_limit: [300, 300], format: :webp, saver: { quality: 80 }
```

### Using Variants in Views

```erb
<%# With named variant %>
<%= image_tag user.avatar.variant(:thumb) %>

<%# Inline variant %>
<%= image_tag user.avatar.variant(resize_to_limit: [200, 200]) %>

<%# With fallback %>
<% if user.avatar.attached? %>
  <%= image_tag user.avatar.variant(:thumb), alt: user.name %>
<% else %>
  <%= image_tag "default-avatar.png", alt: "Default" %>
<% end %>
```

## Controller Handling

### Single Upload

```ruby
# app/controllers/users_controller.rb
class UsersController < ApplicationController
  def update
    if @user.update(user_params)
      redirect_to @user, notice: "Profile updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.require(:user).permit(:name, :email, :avatar)
  end
end
```

### Multiple Uploads

```ruby
# app/controllers/events_controller.rb
class EventsController < ApplicationController
  def update
    if @event.update(event_params)
      redirect_to @event, notice: "Event updated"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def event_params
    params.require(:event).permit(:name, :description, photos: [], documents: [])
  end
end
```

### Removing Attachments

```ruby
class UsersController < ApplicationController
  def remove_avatar
    @user.avatar.purge
    redirect_to edit_user_path(@user), notice: "Avatar removed"
  end
end

# For Turbo Stream
def remove_avatar
  @user.avatar.purge
  respond_to do |format|
    format.turbo_stream { render turbo_stream: turbo_stream.remove("avatar-preview") }
    format.html { redirect_to edit_user_path(@user) }
  end
end
```

## Form Views

### Single File Upload

```erb
<%# app/views/users/_form.html.erb %>
<%= form_with model: @user do |f| %>
  <div class="field">
    <%= f.label :avatar %>
    <%= f.file_field :avatar, accept: "image/png,image/jpeg,image/webp" %>

    <% if @user.avatar.attached? %>
      <div class="mt-2">
        <%= image_tag @user.avatar.variant(:thumb), class: "rounded" %>
        <%= link_to "Remove", remove_avatar_user_path(@user), method: :delete %>
      </div>
    <% end %>
  </div>

  <%= f.submit %>
<% end %>
```

### Multiple File Upload

```erb
<%# app/views/events/_form.html.erb %>
<%= form_with model: @event do |f| %>
  <div class="field">
    <%= f.label :photos %>
    <%= f.file_field :photos, multiple: true, accept: "image/*" %>

    <% if @event.photos.attached? %>
      <div class="grid grid-cols-4 gap-2 mt-2">
        <% @event.photos.each do |photo| %>
          <div class="relative">
            <%= image_tag photo.variant(:thumb), class: "rounded" %>
            <%= button_to "×", remove_photo_event_path(@event, photo_id: photo.id),
                          method: :delete, class: "absolute top-0 right-0" %>
          </div>
        <% end %>
      </div>
    <% end %>
  </div>

  <%= f.submit %>
<% end %>
```

## Direct Uploads

### Setup

```javascript
// app/javascript/application.js
import * as ActiveStorage from "@rails/activestorage"
ActiveStorage.start()
```

### Form with Direct Upload

```erb
<%= form_with model: @event do |f| %>
  <%= f.file_field :photos, multiple: true, direct_upload: true %>
<% end %>
```

### Styling Upload Progress

```css
/* app/assets/stylesheets/direct_uploads.css */
.direct-upload {
  display: inline-block;
  position: relative;
  padding: 2px 4px;
  margin: 0 3px 3px 0;
  border: 1px solid rgba(0, 0, 0, 0.3);
  border-radius: 3px;
  font-size: 11px;
  line-height: 13px;
}

.direct-upload--pending {
  opacity: 0.6;
}

.direct-upload__progress {
  position: absolute;
  top: 0;
  left: 0;
  bottom: 0;
  opacity: 0.2;
  background: #0076ff;
  transition: width 120ms ease-out, opacity 60ms 60ms ease-in;
}

.direct-upload--complete .direct-upload__progress {
  opacity: 0.4;
}

.direct-upload--error {
  border-color: red;
}
```

## Service Methods

### Checking Attachments

```ruby
# Check if attached
user.avatar.attached?

# Get URL (requires controller context or url_for)
url_for(user.avatar)
rails_blob_path(user.avatar, disposition: "attachment")

# Get filename
user.avatar.filename.to_s

# Get content type
user.avatar.content_type

# Get byte size
user.avatar.byte_size
```

### Downloading/Streaming

```ruby
# In controller
def download
  @document = Document.find(params[:id])
  redirect_to rails_blob_path(@document.file, disposition: "attachment")
end

# Or stream directly
def download
  @document = Document.find(params[:id])
  send_data @document.file.download,
            filename: @document.file.filename.to_s,
            content_type: @document.file.content_type
end
```

## Performance Tips

### Eager Loading

```ruby
# Prevent N+1 on attachments
User.with_attached_avatar.limit(10)

# Multiple attachments
Event.with_attached_photos.with_attached_documents
```

### Preloading Variants

```ruby
# In controller
@users = User.with_attached_avatar.limit(10)

# Preload variants
@users.each do |user|
  user.avatar.variant(:thumb).processed if user.avatar.attached?
end
```

## Checklist

- [ ] Active Storage installed and migrated
- [ ] Storage service configured
- [ ] Image processing gem added (if using variants)
- [ ] Attachment added to model
- [ ] Validations added (type, size)
- [ ] Variants defined
- [ ] Controller permits attachment params
- [ ] Form handles file upload
- [ ] Tests written for attachments
- [ ] Direct uploads configured (if needed)
