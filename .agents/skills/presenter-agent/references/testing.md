# Presenter RSpec Tests

## Basic Presenter Tests

```ruby
# spec/presenters/entity_presenter_spec.rb
require 'rails_helper'

RSpec.describe EntityPresenter do
  let(:entity) { create(:entity, name: 'test entity', status: 'published', created_at: Time.zone.local(2024, 12, 25, 10, 30)) }
  let(:presenter) { described_class.new(entity) }

  describe '#formatted_name' do
    it 'titleizes the name' do
      expect(presenter.formatted_name).to eq('Test Entity')
    end
  end

  describe '#formatted_created_at' do
    it 'formats date with time' do
      expect(presenter.formatted_created_at).to eq('December 25, 2024 at 10:30 AM')
    end
  end

  describe '#status_class' do
    context 'when status is published' do
      it 'returns green text class' do
        expect(presenter.status_class).to eq('text-green-600')
      end
    end

    context 'when status is draft' do
      let(:entity) { create(:entity, status: 'draft') }

      it 'returns yellow text class' do
        expect(presenter.status_class).to eq('text-yellow-600')
      end
    end
  end

  describe '#display_description' do
    context 'when description is present' do
      let(:entity) { create(:entity, description: 'A great entity') }

      it 'returns the description' do
        expect(presenter.display_description).to eq('A great entity')
      end
    end

    context 'when description is blank' do
      let(:entity) { create(:entity, description: nil) }

      it 'returns fallback message' do
        expect(presenter.display_description).to eq('No description provided')
      end
    end
  end

  describe '#can_be_edited?' do
    context 'when status is draft' do
      let(:entity) { create(:entity, status: 'draft') }

      it 'returns true' do
        expect(presenter.can_be_edited?).to be true
      end
    end

    context 'when status is published' do
      it 'returns false' do
        expect(presenter.can_be_edited?).to be false
      end
    end
  end
end
```

## Testing with View Context

```ruby
# spec/presenters/user_presenter_spec.rb
require 'rails_helper'

RSpec.describe UserPresenter do
  let(:user) { create(:user, first_name: 'John', last_name: 'Doe', email: 'john@example.com') }
  let(:view_context) { ActionView::Base.new(ActionView::LookupContext.new([]), {}, nil) }
  let(:presenter) { described_class.new(user, view_context) }

  describe '#display_name' do
    it 'returns full name when present' do
      expect(presenter.display_name).to eq('John Doe')
    end

    context 'when name is blank' do
      let(:user) { create(:user, first_name: nil, last_name: nil) }

      it 'returns email username' do
        expect(presenter.display_name).to eq('john')
      end
    end
  end

  describe '#avatar_tag' do
    it 'returns an image tag' do
      expect(presenter.avatar_tag).to include('<img')
      expect(presenter.avatar_tag).to include('avatar')
    end
  end

  describe '#profile_link' do
    before do
      allow(view_context).to receive(:user_path).with(user).and_return('/users/1')
      allow(view_context).to receive(:link_to).and_call_original
    end

    it 'creates a link to user profile' do
      link = presenter.profile_link
      expect(link).to include('John Doe')
      expect(link).to include('/users/1')
    end
  end
end
```

## Testing Number Formatting

```ruby
# spec/presenters/order_presenter_spec.rb
require 'rails_helper'

RSpec.describe OrderPresenter do
  let(:order) { create(:order, total: 12345.67) }
  let(:presenter) { described_class.new(order) }

  describe '#formatted_total' do
    it 'formats total as currency' do
      expect(presenter.formatted_total).to eq('$12,345.67')
    end
  end

  describe '#items_text' do
    context 'with one item' do
      let(:order) { create(:order, items_count: 1) }

      it 'returns singular form' do
        expect(presenter.items_text).to eq('1 item')
      end
    end

    context 'with multiple items' do
      let(:order) { create(:order, items_count: 5) }

      it 'returns plural form' do
        expect(presenter.items_text).to eq('5 items')
      end
    end
  end
end
```
