# Testing I18n

## Missing Translation Detection

```ruby
# spec/rails_helper.rb
RSpec.configure do |config|
  config.around(:each) do |example|
    I18n.exception_handler = ->(exception, *) { raise exception }
    example.run
    I18n.exception_handler = I18n::ExceptionHandler.new
  end
end
```

## Translation Spec

```ruby
# spec/i18n_spec.rb
require "i18n/tasks"

RSpec.describe "I18n" do
  let(:i18n) { I18n::Tasks::BaseTask.new }

  it "has no missing translations" do
    missing = i18n.missing_keys
    expect(missing).to be_empty, "Missing translations:\n#{missing.inspect}"
  end

  it "has no unused translations" do
    unused = i18n.unused_keys
    expect(unused).to be_empty, "Unused translations:\n#{unused.inspect}"
  end

  it "files are normalized" do
    non_normalized = i18n.non_normalized_paths
    expect(non_normalized).to be_empty, "Non-normalized files:\n#{non_normalized.inspect}"
  end
end
```

## View Translation Spec

```ruby
RSpec.describe "events/index", type: :view do
  it "uses translations" do
    assign(:events, [])

    render

    expect(rendered).to include(I18n.t("events.index.title"))
    expect(rendered).to include(I18n.t("events.index.no_events"))
  end
end
```

## i18n-Tasks Gem

### Installation

```ruby
# Gemfile
gem 'i18n-tasks', group: :development
```

### Usage

```bash
# Find missing translations
bundle exec i18n-tasks missing

# Find unused translations
bundle exec i18n-tasks unused

# Add missing translations (interactive)
bundle exec i18n-tasks add-missing

# Normalize locale files
bundle exec i18n-tasks normalize

# Health check
bundle exec i18n-tasks health
```
