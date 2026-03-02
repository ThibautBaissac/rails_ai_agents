---
name: rails-model-generator
description: >-
  Creates Rails models using TDD approach - spec first, then migration, then
  model. Use when creating new models, adding model validations, defining
  associations, or setting up database tables.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec, FactoryBot
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Rails Model Generator (TDD Approach)

## Overview

This skill creates models the TDD way:
1. Define requirements (attributes, validations, associations)
2. Write model spec with expected behavior (RED)
3. Create factory for test data
4. Generate migration
5. Implement model to pass specs (GREEN)
6. Refactor if needed

## Workflow Checklist

```
Model Creation Progress:
- [ ] Step 1: Define requirements (attributes, validations, associations)
- [ ] Step 2: Create model spec (RED)
- [ ] Step 3: Create factory
- [ ] Step 4: Run spec (should fail - no model/table)
- [ ] Step 5: Generate migration
- [ ] Step 6: Run migration
- [ ] Step 7: Create model file (empty)
- [ ] Step 8: Run spec (should fail - no validations)
- [ ] Step 9: Add validations and associations
- [ ] Step 10: Run spec (GREEN)
```

## Step 1: Requirements Template

Before writing code, define the model:

```markdown
## Model: [ModelName]

### Table: [table_name]

### Attributes
| Name | Type | Constraints | Default |
|------|------|-------------|---------|
| name | string | required, unique | - |
| email | string | required, unique, email format | - |
| status | integer | enum | 0 (pending) |
| organization_id | bigint | foreign key | - |

### Associations
- belongs_to :organization
- has_many :posts, dependent: :destroy
- has_one :profile, dependent: :destroy

### Validations
- name: presence, uniqueness, length(max: 100)
- email: presence, uniqueness, format(email)
- status: inclusion in enum values

### Scopes
- active: status = active
- recent: ordered by created_at desc
- by_organization(org): where organization_id = org.id

### Instance Methods
- full_name: combines first_name and last_name
- active?: checks if status is active

### Callbacks
- before_save :normalize_email
- after_create :send_welcome_email
```

## Step 2: Create Model Spec

Location: `spec/models/[model_name]_spec.rb`

```ruby
# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ModelName, type: :model do
  subject { build(:model_name) }

  # === Associations ===
  describe 'associations' do
    it { is_expected.to belong_to(:organization) }
    it { is_expected.to have_many(:posts).dependent(:destroy) }
  end

  # === Validations ===
  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_uniqueness_of(:email).case_insensitive }
    it { is_expected.to validate_length_of(:name).is_at_most(100) }
  end

  # === Scopes ===
  describe '.active' do
    let!(:active_record) { create(:model_name, status: :active) }
    let!(:inactive_record) { create(:model_name, status: :inactive) }

    it 'returns only active records' do
      expect(described_class.active).to include(active_record)
      expect(described_class.active).not_to include(inactive_record)
    end
  end

  # === Instance Methods ===
  describe '#full_name' do
    subject { build(:model_name, first_name: 'John', last_name: 'Doe') }

    it 'returns combined name' do
      expect(subject.full_name).to eq('John Doe')
    end
  end
end
```

## Step 3: Create Factory

Location: `spec/factories/[model_name_plural].rb`

```ruby
# frozen_string_literal: true

FactoryBot.define do
  factory :model_name do
    sequence(:name) { |n| "Name #{n}" }
    sequence(:email) { |n| "user#{n}@example.com" }
    status { :pending }
    association :organization

    trait :active do
      status { :active }
    end

    trait :with_posts do
      after(:create) do |record|
        create_list(:post, 3, model_name: record)
      end
    end
  end
end
```

## Step 4: Run Spec (Verify RED)

```bash
bundle exec rspec spec/models/model_name_spec.rb
```

Expected: Failure because model/table doesn't exist.

## Step 5: Generate Migration

```bash
bin/rails generate migration CreateModelNames \
  name:string \
  email:string:uniq \
  status:integer \
  organization:references
```

Review the generated migration and add:
- Null constraints: `null: false`
- Defaults: `default: 0`
- Indexes: `add_index :table, :column`

```ruby
# db/migrate/YYYYMMDDHHMMSS_create_model_names.rb
class CreateModelNames < ActiveRecord::Migration[8.0]
  def change
    create_table :model_names do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.integer :status, null: false, default: 0
      t.references :organization, null: false, foreign_key: true

      t.timestamps
    end

    add_index :model_names, :email, unique: true
    add_index :model_names, :status
  end
end
```

## Step 6: Run Migration

```bash
bin/rails db:migrate
```

Verify with:
```bash
bin/rails db:migrate:status
```

## Step 7: Create Model File

Location: `app/models/[model_name].rb`

```ruby
# frozen_string_literal: true

class ModelName < ApplicationRecord
end
```

## Step 8: Run Spec (Still RED)

```bash
bundle exec rspec spec/models/model_name_spec.rb
```

Expected: Failures for missing validations/associations.

## Step 9: Add Validations & Associations

```ruby
# frozen_string_literal: true

class ModelName < ApplicationRecord
  # === Associations ===
  belongs_to :organization
  has_many :posts, dependent: :destroy

  # === Enums ===
  enum :status, { pending: 0, active: 1, suspended: 2 }

  # === Validations ===
  validates :name, presence: true,
                   uniqueness: true,
                   length: { maximum: 100 }
  validates :email, presence: true,
                    uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  # === Scopes ===
  scope :active, -> { where(status: :active) }
  scope :recent, -> { order(created_at: :desc) }

  # === Instance Methods ===
  def full_name
    "#{first_name} #{last_name}".strip
  end
end
```

## Step 10: Run Spec (GREEN)

```bash
bundle exec rspec spec/models/model_name_spec.rb
```

All specs should pass.

## References

- See [reference/validations.md](references/validations.md) for validation patterns

## Common Patterns

### Enum with Validation

```ruby
enum :status, { draft: 0, published: 1, archived: 2 }
validates :status, inclusion: { in: statuses.keys }
```

### Polymorphic Association

```ruby
belongs_to :commentable, polymorphic: true
```

### Counter Cache

```ruby
belongs_to :organization, counter_cache: true
# Add: organization.posts_count column
```

### Soft Delete

```ruby
scope :active, -> { where(deleted_at: nil) }
scope :deleted, -> { where.not(deleted_at: nil) }

def soft_delete
  update(deleted_at: Time.current)
end
```
