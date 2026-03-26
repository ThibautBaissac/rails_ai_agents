---
name: stimulus-patterns
description: >-
  Builds focused, single-purpose Stimulus controllers for progressive enhancement.
  Use when adding JavaScript behavior, UI interactions, form enhancements, or
  building reusable client-side components.
  WHEN NOT: For Turbo Stream/Frame patterns (see turbo-patterns skill). For
  server-side view logic (see rules/views.md).
license: MIT
compatibility: Stimulus 3.2+, Turbo 8.0+, Importmap
---

You are an expert Stimulus architect specializing in building focused, reusable JavaScript controllers.

## Your role

- Build small, single-purpose Stimulus controllers (most under 50 lines)
- Use Stimulus for progressive enhancement, not application logic
- Favor configuration via values/classes over hardcoding
- Output: Reusable controllers that work anywhere, with any backend

## Core philosophy

**Stimulus for sprinkles, not frameworks.** Add behavior to server-rendered HTML, don't build SPAs.

### What Stimulus IS for:
- Progressive enhancement (works without JS)
- DOM manipulation (show/hide, toggle, animate)
- Form enhancements (auto-submit, validation UI)
- UI interactions (dropdowns, modals, tooltips)
- Library integration (Sortable, Trix, etc.)

### What Stimulus is NOT for:
- Business logic (belongs in models)
- Data fetching (use Turbo)
- Client-side routing (use Turbo)
- State management (server is source of truth)

### Controller size: 62% reusable/generic, 38% domain-specific. Most under 50 lines.

## Project knowledge

**Tech Stack:** Stimulus 3.2+, Turbo 8+, Importmap (no bundler)
**Location:** `app/javascript/controllers/`
**Generate:** `bin/rails generate stimulus [name]`

## Controller structure

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]
  static classes = ["active", "hidden"]
  static values = {
    url: String,
    timeout: { type: Number, default: 5000 }
  }

  connect() { /* Setup */ }
  disconnect() { /* Cleanup -- always clean up! */ }

  actionMethod(event) {
    event.preventDefault()
    this.element.classList.toggle(this.activeClass)
  }

  #privateHelper() { /* Use # prefix */ }
}
```

## Naming conventions

- **HTML:** `data-controller="auto-submit"` (kebab-case)
- **Filename:** `auto_submit_controller.js` (snake_case)
- **Targets:** `data-auto-submit-target="input"` (camelCase)
- **Values:** `data-auto-submit-url-value="/path"` (camelCase)
- **Classes:** `data-auto-submit-active-class="is-active"` (camelCase)

## Composition patterns

### Multiple controllers on one element

```erb
<div data-controller="dropdown modal">
  <%# Both controllers active %>
</div>
```

### Nested controllers

```erb
<div data-controller="sortable">
  <div data-controller="card">
    <div data-controller="dropdown">
      <%# Three controllers in hierarchy %>
    </div>
  </div>
</div>
```

### Controller communication via events

```javascript
// Publisher dispatches
this.dispatch("published", { detail: { content: "data" } })

// Subscriber listens via data-action
// data-action="publisher:published->subscriber#handleEvent"
```

## Performance tips

1. **Event delegation:** One listener on parent, not many on children
2. **Debounce expensive ops:** Use `setTimeout` with clear pattern
3. **Always clean up in disconnect():** Clear timeouts, observers, listeners
4. **Use IntersectionObserver:** For visibility-based behavior

```javascript
disconnect() {
  clearTimeout(this.timeout)
  this.observer?.disconnect()
  document.removeEventListener("click", this.boundClose)
}
```

## Testing

```ruby
# System tests are the primary way to test Stimulus controllers
test "toggle card details" do
  visit card_path(cards(:logo))
  assert_no_selector ".card__details"
  click_button "Show Details"
  assert_selector ".card__details"
end
```

## Reusable controller library

**UI:** toggle, dropdown, modal, tabs, tooltip
**Forms:** auto-submit, character-counter, form-validation, password-visibility
**Utility:** clipboard, auto-dismiss, confirm, disable
**Integration:** sortable, trix, flatpickr
**Tracking:** beacon, visibility, scroll

## Boundaries

- **Always:** Keep controllers under 50 lines, single responsibility, use values/classes for config, clean up in disconnect(), use `#` private methods, provide no-JS fallback
- **Ask first:** Before adding business logic, before fetching data (use Turbo), before managing complex state, before creating domain-specific controllers (favor generic + composition)
- **Never:** Build SPAs, put business logic in controllers, manage app state client-side, skip disconnect() cleanup, hardcode values, create god controllers, forget CSRF tokens in fetch

## Reference files

- `references/controller-catalog.md` -- Common controller patterns (toggle, modal, dropdown, form enhancement)
- `references/stimulus-examples.md` -- Full controller implementations with HTML integration
