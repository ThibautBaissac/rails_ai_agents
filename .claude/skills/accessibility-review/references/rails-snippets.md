# Rails Accessibility Snippets

Drop-in remediations for this stack (Rails 8.1 + Hotwire + Tailwind 4 +
ViewComponent). Adapt namespaces to the project.

## 1. Layout skeleton

```erb
<%# app/views/layouts/application.html.erb %>
<!DOCTYPE html>
<html lang="<%= I18n.locale %>">
  <head>
    <title><%= content_for?(:title) ? yield(:title) : "Rails AI Agents" %></title>
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>
  <body class="min-h-dvh bg-white text-gray-900">
    <a href="#main"
       class="sr-only focus:not-sr-only focus:fixed focus:top-2 focus:left-2
              focus:z-50 focus:bg-white focus:px-3 focus:py-2 focus:rounded
              focus:ring-2 focus:ring-blue-600">
      Skip to main content
    </a>

    <header role="banner"><%= render "shared/navbar" %></header>

    <div id="flash"
         role="status"
         aria-live="polite"
         aria-atomic="true"
         class="sr-only-when-empty">
      <%= render "shared/flash" %>
    </div>

    <main id="main" tabindex="-1"><%= yield %></main>

    <footer role="contentinfo"><%= render "shared/footer" %></footer>
  </body>
</html>
```

Key points:

- `<html lang>` set (1.3.1 is already met; 3.1.1 covered).
- Skip link is the first focusable element (2.4.1).
- Live region for flash (4.1.3).
- `<main>` has `tabindex="-1"` so the focus-on-navigate controller below can
  move focus to it.

## 2. Focus-on-navigate Stimulus controller

Move focus to `<main>` after Turbo navigations so screen-reader users hear
the new page's heading (2.4.3, 4.1.3).

```js
// app/javascript/controllers/focus_main_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    document.addEventListener("turbo:load", this.focusMain)
    document.addEventListener("turbo:frame-load", this.focusMain)
  }

  disconnect() {
    document.removeEventListener("turbo:load", this.focusMain)
    document.removeEventListener("turbo:frame-load", this.focusMain)
  }

  focusMain = () => {
    const main = document.getElementById("main")
    if (main) main.focus({ preventScroll: true })
  }
}
```

Attach on `<body data-controller="focus-main">` in the layout.

## 3. Accessible flash partial

```erb
<%# app/views/shared/_flash.html.erb %>
<% flash.each do |type, message| %>
  <div class="rounded-md px-4 py-3 <%= type == :alert ? 'bg-red-50 text-red-900' : 'bg-green-50 text-green-900' %>"
       role="<%= type == :alert ? 'alert' : 'status' %>">
    <%= message %>
  </div>
<% end %>
```

Polite for notices, assertive for alerts.

## 4. Form with accessible errors

```erb
<%= form_with model: @user, class: "space-y-4" do |f| %>
  <% if @user.errors.any? %>
    <div role="alert" class="rounded-md bg-red-50 p-4 text-red-900"
         data-controller="focus-on-mount">
      <h2 class="font-semibold">
        <%= pluralize(@user.errors.count, "error") %> prevented this save
      </h2>
      <ul class="list-disc pl-5">
        <% @user.errors.full_messages.each do |msg| %>
          <li><%= msg %></li>
        <% end %>
      </ul>
    </div>
  <% end %>

  <div>
    <%= f.label :email, class: "block font-medium" %>
    <%= f.email_field :email,
          required: true,
          autocomplete: "email",
          "aria-invalid": @user.errors[:email].any?,
          "aria-describedby": ("email-error" if @user.errors[:email].any?),
          class: "mt-1 block w-full rounded border-gray-300 focus:border-blue-600
                 focus:ring-2 focus:ring-blue-600" %>
    <% if @user.errors[:email].any? %>
      <p id="email-error" class="mt-1 text-sm text-red-700">
        <%= @user.errors[:email].to_sentence %>
      </p>
    <% end %>
  </div>

  <%= f.submit "Save", class: "rounded bg-blue-600 px-4 py-2 text-white
                                 focus-visible:ring-2 focus-visible:ring-offset-2
                                 focus-visible:ring-blue-600" %>
<% end %>
```

Companion Stimulus controller to focus the error summary on mount:

```js
// app/javascript/controllers/focus_on_mount_controller.js
import { Controller } from "@hotwired/stimulus"
export default class extends Controller {
  connect() { this.element.setAttribute("tabindex", "-1"); this.element.focus() }
}
```

## 5. Icon button ViewComponent

```ruby
# app/components/icon_button_component.rb
class IconButtonComponent < ViewComponent::Base
  def initialize(label:, icon:, **html_options)
    @label = label
    @icon = icon
    @html_options = html_options
  end

  def call
    content_tag :button,
                type: "button",
                "aria-label": @label,
                class: "inline-flex items-center justify-center p-2 rounded
                        min-h-[44px] min-w-[44px] focus-visible:ring-2
                        focus-visible:ring-blue-600 focus-visible:ring-offset-2
                        #{@html_options[:class]}",
                **@html_options.except(:class) do
      inline_svg_tag("#{@icon}.svg", class: "h-5 w-5", "aria-hidden": true)
    end
  end
end
```

Minimum touch target ≥ 44×44 (beats 2.5.8's 24×24 floor), explicit
`aria-label`, focus ring preserved.

## 6. Tailwind utilities worth adding

```css
/* app/assets/stylesheets/accessibility.css */

.sr-only {
  position: absolute;
  width: 1px;
  height: 1px;
  padding: 0;
  margin: -1px;
  overflow: hidden;
  clip: rect(0, 0, 0, 0);
  white-space: nowrap;
  border-width: 0;
}

.focus\:not-sr-only:focus {
  position: static;
  width: auto;
  height: auto;
  margin: 0;
  overflow: visible;
  clip: auto;
  white-space: normal;
}

@media (prefers-reduced-motion: reduce) {
  *, *::before, *::after {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
    scroll-behavior: auto !important;
  }
}
```

## 7. RSpec a11y system spec

```ruby
# spec/system/accessibility/home_spec.rb
require "rails_helper"
require "axe-rspec"

RSpec.describe "Accessibility — home", :js, type: :system do
  it "has no axe violations" do
    visit root_path
    expect(page).to be_axe_clean
      .according_to(:wcag2a, :wcag2aa, :wcag22aa)
      .skipping("color-contrast") # only while tokens are being fixed
  end
end
```

Add a shared example to DRY across pages:

```ruby
# spec/support/shared_examples/accessible_page.rb
RSpec.shared_examples "an accessible page" do |path|
  it "passes axe-core at WCAG 2.2 AA" do
    visit path
    expect(page).to be_axe_clean.according_to(:wcag22aa)
  end
end
```

## 8. `rails generate` helper for accessible CRUD views

Override the scaffold templates at `lib/templates/erb/scaffold/` so new
forms ship with labels, `autocomplete`, and `aria-describedby` for errors by
default. This removes a whole class of regressions at the generator level.

## 9. Brakeman-style a11y pre-commit check

Add a Lefthook or Husky hook that runs `bundle exec herb lint app/views
app/components` and `npx pa11y-ci` against a local server before commits
touching view files. Keep the CI job non-blocking initially; flip to
blocking once the baseline is green.

## 10. Language switcher

```erb
<nav aria-label="Language">
  <ul class="flex gap-2">
    <% I18n.available_locales.each do |locale| %>
      <li>
        <%= link_to t("languages.#{locale}"),
              url_for(locale: locale),
              lang: locale.to_s,
              "aria-current": ("true" if I18n.locale == locale) %>
      </li>
    <% end %>
  </ul>
</nav>
```

`lang` on each link marks the language of the link text (3.1.2);
`aria-current` announces the active choice (4.1.2).
