---
name: i18n-patterns
description: >-
  Implements internationalization with Rails I18n for multi-language support.
  Use when adding translations, managing locales, localizing dates/currencies,
  pluralization, or when user mentions i18n, translations, locales, or
  multi-language. WHEN NOT: English-only applications without localization
  needs, formatting handled by presenters, or date/number formatting in
  non-user-facing code.
paths: "config/locales/**/*.yml, app/views/**/*.erb"
---

# I18n Patterns for Rails 8

## Overview

Rails I18n provides internationalization support:
- Translation lookups
- Locale management
- Date/time/currency formatting
- Pluralization rules
- Lazy lookups in views

## Quick Start

```ruby
# config/application.rb
config.i18n.default_locale = :en
config.i18n.available_locales = [:en, :fr, :de]
config.i18n.fallbacks = true
```

## Project Structure

```
config/locales/
├── en.yml                    # English defaults
├── fr.yml                    # French defaults
├── models/
│   ├── en.yml               # Model translations (EN)
│   └── fr.yml               # Model translations (FR)
├── views/
│   ├── en.yml               # View translations (EN)
│   └── fr.yml               # View translations (FR)
├── mailers/
│   ├── en.yml               # Mailer translations (EN)
│   └── fr.yml               # Mailer translations (FR)
└── components/
    ├── en.yml               # Component translations (EN)
    └── fr.yml               # Component translations (FR)
```

## Locale File Organization

Organize locale files by domain: `models/`, `views/`, `mailers/`, `components/`.

- **Models:** `activerecord.models`, `activerecord.attributes`, `activerecord.errors`
- **Views:** nested under controller name and action (e.g. `events.index.title`)
- **Shared:** `common.actions`, `common.messages`, `common.date.formats`
- **Components:** `components.<component_name>.<key>`

See [locale-files.md](references/locale-files.md) for complete YAML examples for models, views, shared keys, and components.

## Usage Patterns

### Key Principles

- Use **lazy lookup** in views: `t(".title")` resolves to `"events.index.title"`
- Use **`_html` suffix** for strings containing HTML markup
- Use **`I18n.l`** (localize) for dates, times, and numbers — not `I18n.t`
- Use **`I18n.t`** with full key path in models, services, and presenters
- Pass dynamic values via **interpolation**: `t(".greeting", name: user.name)`

### In Views

```erb
<h1><%= t(".title") %></h1>
<%= link_to t(".new_event"), new_event_path %>
<p><%= t(".welcome", name: current_user.name) %></p>
<p><%= t(".intro_html", link: link_to("here", help_path)) %></p>
```

### In Controllers

```ruby
redirect_to @event, notice: t(".success")
```

### In Models/Presenters

```ruby
I18n.t("activerecord.attributes.event/statuses.#{status}")
I18n.l(event_date, format: :long)
```

See [usage-patterns.md](references/usage-patterns.md) for full examples including presenters, components, date/currency formatting, and pluralization.

## Locale Switching

### URL-Based Locale

```ruby
# config/routes.rb
Rails.application.routes.draw do
  scope "(:locale)", locale: /en|fr|de/ do
    resources :events
  end
end

# app/controllers/application_controller.rb
class ApplicationController < ActionController::Base
  around_action :switch_locale

  private

  def switch_locale(&action)
    locale = params[:locale] || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def default_url_options
    { locale: I18n.locale }
  end
end
```

### User Preference Locale

```ruby
class ApplicationController < ActionController::Base
  around_action :switch_locale

  private

  def switch_locale(&action)
    locale = current_user&.locale || extract_locale_from_header || I18n.default_locale
    I18n.with_locale(locale, &action)
  end

  def extract_locale_from_header
    request.env['HTTP_ACCEPT_LANGUAGE']&.scan(/^[a-z]{2}/)&.first
  end
end
```

## Testing I18n

- Raise on missing translations in `spec/rails_helper.rb`
- Use `i18n-tasks` gem to detect missing and unused keys
- Write view translation specs to assert rendered content

See [testing.md](references/testing.md) for complete spec examples and i18n-tasks configuration.

## Best Practices

### DO

```yaml
# Use nested structure matching view paths
en:
  events:
    index:
      title: Events
    show:
      title: Event Details

# Use interpolation for dynamic content
en:
  greeting: "Hello, %{name}!"

# Use _html suffix for HTML content
en:
  intro_html: "Welcome to <strong>our app</strong>"
```

### DON'T

```yaml
# Don't use flat keys
en:
  events_index_title: Events  # BAD

# Don't hardcode in views
<h1>Events</h1>  # BAD - use t(".title")

# Don't concatenate translations
t("hello") + " " + t("world")  # BAD
```

## Checklist

- [ ] Locale files organized by domain (models, views, etc.)
- [ ] All user-facing text uses I18n
- [ ] Lazy lookups in views (t(".key"))
- [ ] Pluralization for countable items
- [ ] Date/currency formatting localized
- [ ] Locale switching implemented
- [ ] i18n-tasks configured
- [ ] Missing translation detection in tests
- [ ] Fallbacks configured

## References

- [locale-files.md](references/locale-files.md) — YAML locale file examples for models, views, shared keys, and components
- [usage-patterns.md](references/usage-patterns.md) — Usage examples in views, controllers, models, presenters, components, and formatting
- [testing.md](references/testing.md) — RSpec specs and i18n-tasks for translation coverage
