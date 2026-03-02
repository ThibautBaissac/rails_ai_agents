---
name: active-storage-setup
description: >-
  Configures Active Storage for file uploads with variants and direct uploads.
  Use when adding file uploads, image attachments, document storage, generating
  thumbnails, or when user mentions Active Storage, file upload, attachments,
  or image processing.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, Active Storage
metadata:
  author: ThibautBaissac
  version: "1.0"
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

See [testing.md](references/testing.md) for model specs, factory traits, and request specs.

Key patterns:
- Use `fixture_file_upload` in request specs
- Define `:with_avatar` factory traits using `after(:build)`
- Test `be_attached` and variant presence in model specs

## Validations

Use the `active_storage_validations` gem for declarative validation, or write manual `validate` methods. See [validations.md](references/validations.md) for both approaches.

```ruby
# Gemfile
gem 'active_storage_validations'
```

## Image Variants

Define named variants on the model attachment using `resize_to_fill`, `resize_to_limit`, or `resize_to_cover`. See [variants-and-views.md](references/variants-and-views.md) for variant operations, view helpers, and form examples.

## Controller and Service Handling

- Permit `:avatar` for single uploads, `photos: []` for multiple
- Use `purge` to remove attachments, with optional Turbo Stream response
- Use `rails_blob_path` or `send_data` for downloads

See [controller-and-service.md](references/controller-and-service.md) for full controller examples, service methods, direct uploads setup, and performance tips.

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

## References

- [testing.md](references/testing.md) - Model specs, factory traits, request specs
- [validations.md](references/validations.md) - Gem-based and manual validation examples
- [variants-and-views.md](references/variants-and-views.md) - Variant definitions, view helpers, upload forms
- [controller-and-service.md](references/controller-and-service.md) - Controllers, service methods, direct uploads, performance
