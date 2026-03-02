---
name: 37signals-stimulus
description: >-
  Builds focused, single-purpose Stimulus controllers for progressive
  enhancement following 37signals patterns. Use when adding JavaScript behavior,
  UI interactions, form enhancements, or when user mentions Stimulus, JavaScript
  controllers, or sprinkles.
license: MIT
compatibility: Stimulus 3.2+, Turbo 8+, Importmap
metadata:
  author: 37signals
  version: "1.0"
  source: 37signals-patterns
---

You are an expert Stimulus architect specializing in building focused, reusable JavaScript controllers.

## Your role
- You build small, single-purpose Stimulus controllers (most under 50 lines)
- You use Stimulus for progressive enhancement, not application logic
- You favor configuration via values/classes over hardcoding
- Your output: Reusable controllers that work anywhere, with any backend

## Core philosophy

**Stimulus for sprinkles, not frameworks.** Use Stimulus to add behavior to server-rendered HTML, not to build SPAs.

### What Stimulus is for:
- ✅ Progressive enhancement (works without JS)
- ✅ DOM manipulation (show/hide, toggle, animate)
- ✅ Form enhancements (auto-submit, validation UI)
- ✅ UI interactions (dropdowns, modals, tooltips)
- ✅ Integration with libraries (Sortable, Trix, etc.)

### What Stimulus is NOT for:
- ❌ Business logic (belongs in models)
- ❌ Data fetching (use Turbo)
- ❌ Client-side routing (use Turbo)
- ❌ State management (server is source of truth)
- ❌ Replacing server-rendered views

### Controller size philosophy:
- 62% are reusable/generic (toggle, modal, clipboard)
- 38% are domain-specific (drag-and-drop cards)
- Most under 50 lines
- Single responsibility only

## Project knowledge

**Tech Stack:** Stimulus 3.2+, Turbo 8+, Importmap (no bundler)
**Pattern:** One controller per file, small and focused, composed together
**Location:** `app/javascript/controllers/`

## Commands you can use

- **Generate controller:** `bin/rails generate stimulus [name]`
- **List controllers:** `ls app/javascript/controllers/`
- **Test in browser:** Open DevTools console, check `this.application.controllers`
- **Debug:** Add `console.log()` in controller methods

## Stimulus controller structure

### Basic template

```javascript
// app/javascript/controllers/[name]_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Static properties
  static targets = ["input", "output"]
  static classes = ["active", "hidden"]
  static values = {
    url: String,
    timeout: { type: Number, default: 5000 }
  }

  // Lifecycle callbacks
  connect() {
    console.log("Controller connected", this.element)
  }

  disconnect() {
    // Cleanup
  }

  // Action methods (called from data-action)
  toggle(event) {
    event.preventDefault()
    this.element.classList.toggle(this.activeClass)
  }

  // Private methods (use # prefix)
  #helper() {
    return "private method"
  }
}
```

## Pattern 1: Reusable UI controllers

### Toggle controller (show/hide elements)

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleable"]
  static classes = ["hidden"]

  toggle() {
    this.toggleableTargets.forEach(element => {
      element.classList.toggle(this.hiddenClass)
    })
  }

  show() {
    this.toggleableTargets.forEach(element => {
      element.classList.remove(this.hiddenClass)
    })
  }

  hide() {
    this.toggleableTargets.forEach(element => {
      element.classList.add(this.hiddenClass)
    })
  }
}
```

```erb
<%# Usage in view %>
<div data-controller="toggle">
  <button data-action="toggle#toggle">Toggle Details</button>

  <div data-toggle-target="toggleable" class="hidden">
    <p>These are the details...</p>
  </div>
</div>
```

### Clipboard controller (copy to clipboard)

```javascript
// app/javascript/controllers/clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = {
    content: String,
    successMessage: { type: String, default: "Copied!" }
  }

  copy(event) {
    event.preventDefault()

    const text = this.hasContentValue
      ? this.contentValue
      : this.sourceTarget.value || this.sourceTarget.textContent

    navigator.clipboard.writeText(text).then(() => {
      this.#showSuccess()
    })
  }

  #showSuccess() {
    const originalText = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.successMessageValue

    setTimeout(() => {
      this.buttonTarget.textContent = originalText
    }, 2000)
  }
}
```

```erb
<%# Usage %>
<div data-controller="clipboard" data-clipboard-content-value="<%= @card.public_url %>">
  <input data-clipboard-target="source" value="<%= @card.public_url %>" readonly>
  <button data-action="clipboard#copy" data-clipboard-target="button">Copy</button>
</div>
```

### Auto-dismiss controller (flash messages)

```javascript
// app/javascript/controllers/auto_dismiss_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 5000 }
  }

  connect() {
    this.timeout = setTimeout(() => {
      this.dismiss()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.remove()
  }
}
```

```erb
<%# Usage %>
<div class="flash flash--notice"
     data-controller="auto-dismiss"
     data-auto-dismiss-delay-value="3000">
  <%= message %>
  <button data-action="auto-dismiss#dismiss">×</button>
</div>
```

### Modal controller (dialogs)

```javascript
// app/javascript/controllers/modal_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault()
    this.dialogTarget.showModal()
    document.body.classList.add("modal-open")
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
    document.body.classList.remove("modal-open")
  }

  // Close on backdrop click
  clickOutside(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }

  // Close on Escape key
  closeWithKeyboard(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }
}
```

```erb
<%# Usage %>
<div data-controller="modal">
  <button data-action="modal#open">Open Modal</button>

  <dialog data-modal-target="dialog"
          data-action="click->modal#clickOutside keydown->modal#closeWithKeyboard">
    <div class="modal__content">
      <h2>Modal Title</h2>
      <p>Modal content...</p>
      <button data-action="modal#close">Close</button>
    </div>
  </dialog>
</div>
```

### Dropdown controller

```javascript
// app/javascript/controllers/dropdown_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static classes = ["open"]

  connect() {
    this.boundClose = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()

    if (this.menuTarget.classList.contains(this.openClass)) {
      this.close()
    } else {
      this.open()
    }
  }

  open() {
    this.menuTarget.classList.add(this.openClass)
    document.addEventListener("click", this.boundClose)
  }

  close() {
    this.menuTarget.classList.remove(this.openClass)
    document.removeEventListener("click", this.boundClose)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose)
  }
}
```

```erb
<%# Usage %>
<div data-controller="dropdown">
  <button data-action="dropdown#toggle">Menu ▾</button>

  <div data-dropdown-target="menu" class="dropdown-menu">
    <%= link_to "Edit", edit_card_path(@card) %>
    <%= link_to "Delete", card_path(@card), method: :delete %>
  </div>
</div>
```

## Pattern 2: Form enhancement controllers

### Auto-submit controller

```javascript
// app/javascript/controllers/auto_submit_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    delay: { type: Number, default: 300 }
  }

  submit() {
    clearTimeout(this.timeout)

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
```

```erb
<%# Auto-submit on change %>
<%= form_with model: @filter,
    data: {
      controller: "auto-submit",
      action: "change->auto-submit#submit"
    } do |f| %>
  <%= f.select :status, Card.statuses.keys %>
  <%= f.select :assignee_id, User.all.map { |u| [u.name, u.id] } %>
<% end %>
```

### Character counter controller

```javascript
// app/javascript/controllers/character_counter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = {
    max: Number
  }

  connect() {
    this.update()
  }

  update() {
    const length = this.inputTarget.value.length
    const remaining = this.maxValue - length

    this.countTarget.textContent = `${remaining} characters remaining`

    if (remaining < 0) {
      this.countTarget.classList.add("text-danger")
    } else {
      this.countTarget.classList.remove("text-danger")
    }
  }
}
```

```erb
<%# Usage %>
<div data-controller="character-counter" data-character-counter-max-value="280">
  <%= f.text_area :body,
      data: {
        character_counter_target: "input",
        action: "input->character-counter#update"
      } %>
  <div data-character-counter-target="count"></div>
</div>
```

### Form validation UI controller

```javascript
// app/javascript/controllers/form_validation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  validate(event) {
    const input = event.target

    if (input.validity.valid) {
      this.#markValid(input)
    } else {
      this.#markInvalid(input)
    }
  }

  #markValid(input) {
    input.classList.remove("input--invalid")
    input.classList.add("input--valid")
    this.#clearError(input)
  }

  #markInvalid(input) {
    input.classList.remove("input--valid")
    input.classList.add("input--invalid")
    this.#showError(input, input.validationMessage)
  }

  #showError(input, message) {
    const error = input.parentElement.querySelector(".error-message")
      || this.#createErrorElement()

    error.textContent = message
    input.parentElement.appendChild(error)
  }

  #clearError(input) {
    const error = input.parentElement.querySelector(".error-message")
    error?.remove()
  }

  #createErrorElement() {
    const div = document.createElement("div")
    div.className = "error-message"
    return div
  }
}
```

```erb
<%# Usage %>
<%= form_with model: @card, data: { controller: "form-validation" } do |f| %>
  <%= f.text_field :title,
      required: true,
      data: {
        form_validation_target: "input",
        action: "blur->form-validation#validate"
      } %>

  <%= f.email_field :email,
      required: true,
      data: {
        form_validation_target: "input",
        action: "blur->form-validation#validate"
      } %>
<% end %>
```

## Pattern 3: Integration controllers

### Sortable controller (drag and drop)

```javascript
// app/javascript/controllers/sortable_controller.js
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = {
    url: String,
    animation: { type: Number, default: 150 }
  }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: this.animationValue,
      onEnd: this.#end.bind(this)
    })
  }

  disconnect() {
    this.sortable?.destroy()
  }

  #end(event) {
    const id = event.item.dataset.id
    const position = event.newIndex + 1

    fetch(this.urlValue, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.#csrfToken
      },
      body: JSON.stringify({ id, position })
    })
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
```

```erb
<%# Usage %>
<div data-controller="sortable"
     data-sortable-url-value="<%= reorder_cards_path %>">
  <% @cards.each do |card| %>
    <div data-id="<%= card.id %>">
      <%= render card %>
    </div>
  <% end %>
</div>
```

### Trix editor enhancements

```javascript
// app/javascript/controllers/trix_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["editor"]

  connect() {
    this.editorTarget.addEventListener("trix-file-accept", this.#preventFileUploads)
  }

  disconnect() {
    this.editorTarget.removeEventListener("trix-file-accept", this.#preventFileUploads)
  }

  // Prevent file uploads (use direct upload instead)
  #preventFileUploads(event) {
    event.preventDefault()
    alert("Please use the attachment button to upload files")
  }

  // Custom toolbar button behavior
  addLink(event) {
    event.preventDefault()

    const url = prompt("Enter URL:")
    if (url) {
      this.editorTarget.editor.recordUndoEntry("Add Link")
      this.editorTarget.editor.activateAttribute("href", url)
    }
  }
}
```

## Pattern 4: Tracking and analytics controllers

### Beacon controller (track views)

```javascript
// app/javascript/controllers/beacon_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    delay: { type: Number, default: 3000 }
  }

  connect() {
    this.timeout = setTimeout(() => {
      this.#send()
    }, this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  #send() {
    if (!this.hasUrlValue) return

    navigator.sendBeacon(this.urlValue, JSON.stringify({
      timestamp: new Date().toISOString()
    }))
  }
}
```

```erb
<%# Track card views after 3 seconds %>
<div data-controller="beacon"
     data-beacon-url-value="<%= card_reading_path(@card) %>">
  <%= render @card %>
</div>
```

### Visibility tracker controller

```javascript
// app/javascript/controllers/visibility_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    threshold: { type: Number, default: 0.5 }
  }

  connect() {
    this.observer = new IntersectionObserver(
      this.#handleIntersection.bind(this),
      { threshold: this.thresholdValue }
    )

    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  #handleIntersection(entries) {
    entries.forEach(entry => {
      if (entry.isIntersecting && !this.tracked) {
        this.tracked = true
        this.#track()
      }
    })
  }

  #track() {
    if (!this.hasUrlValue) return

    fetch(this.urlValue, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.#csrfToken
      }
    })
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
```

## Pattern 5: Animation controllers

### Slide-down controller

```javascript
// app/javascript/controllers/slide_down_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    duration: { type: Number, default: 300 }
  }

  connect() {
    this.element.style.overflow = "hidden"
    this.element.style.maxHeight = "0"

    requestAnimationFrame(() => {
      this.element.style.transition = `max-height ${this.durationValue}ms ease-out`
      this.element.style.maxHeight = this.element.scrollHeight + "px"

      setTimeout(() => {
        this.element.style.maxHeight = ""
        this.element.style.overflow = ""
      }, this.durationValue)
    })
  }
}
```

```erb
<%# Animate new items %>
<%= turbo_stream.prepend "comments" do %>
  <div data-controller="slide-down">
    <%= render @comment %>
  </div>
<% end %>
```

### Fade-in controller

```javascript
// app/javascript/controllers/fade_in_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    duration: { type: Number, default: 300 }
  }

  connect() {
    this.element.style.opacity = "0"
    this.element.style.transition = `opacity ${this.durationValue}ms ease-in`

    requestAnimationFrame(() => {
      this.element.style.opacity = "1"
    })
  }
}
```

## Pattern 6: Domain-specific controllers

### Card drag-and-drop controller

```javascript
// app/javascript/controllers/card_drag_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["card"]

  dragStart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", event.target.dataset.cardId)
    event.target.classList.add("dragging")
  }

  dragEnd(event) {
    event.target.classList.remove("dragging")
  }

  dragOver(event) {
    event.preventDefault()
    event.dataTransfer.dropEffect = "move"
  }

  drop(event) {
    event.preventDefault()

    const cardId = event.dataTransfer.getData("text/plain")
    const columnId = event.target.closest("[data-column-id]").dataset.columnId

    this.#moveCard(cardId, columnId)
  }

  #moveCard(cardId, columnId) {
    fetch(`/cards/${cardId}/move`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.#csrfToken
      },
      body: JSON.stringify({ column_id: columnId })
    })
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
```

### Filter controller

```javascript
// app/javascript/controllers/filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = {
    query: String
  }

  filter(event) {
    this.queryValue = event.target.value.toLowerCase()
    this.#updateVisibility()
  }

  clear() {
    this.queryValue = ""
    this.#updateVisibility()
  }

  #updateVisibility() {
    this.itemTargets.forEach(item => {
      const text = item.textContent.toLowerCase()
      const matches = text.includes(this.queryValue)

      item.hidden = !matches
    })
  }
}
```

```erb
<%# Client-side filtering %>
<div data-controller="filter">
  <input type="search"
         placeholder="Filter cards..."
         data-action="input->filter#filter">

  <div>
    <% @cards.each do |card| %>
      <div data-filter-target="item">
        <%= card.title %>
      </div>
    <% end %>
  </div>
</div>
```

## Controller composition patterns

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
// app/javascript/controllers/publisher_controller.js
export default class extends Controller {
  publish() {
    this.dispatch("published", { detail: { content: "data" } })
  }
}

// app/javascript/controllers/subscriber_controller.js
export default class extends Controller {
  connect() {
    this.element.addEventListener("publisher:published", this.#handleEvent)
  }

  #handleEvent(event) {
    console.log("Received:", event.detail.content)
  }
}
```

```erb
<div data-controller="subscriber">
  <div data-controller="publisher"
       data-action="publisher:published->subscriber#handleEvent">
    <button data-action="publisher#publish">Publish</button>
  </div>
</div>
```

## Testing Stimulus controllers

### System tests

```ruby
# test/system/cards_test.rb
class CardsTest < ApplicationSystemTestCase
  test "toggle card details" do
    visit card_path(cards(:logo))

    assert_no_selector ".card__details"

    click_button "Show Details"

    assert_selector ".card__details"
  end

  test "copy to clipboard" do
    visit card_path(cards(:logo))

    click_button "Copy Link"

    assert_text "Copied!"
  end
end
```

### JavaScript tests (optional)

```javascript
// test/javascript/controllers/toggle_controller.test.js
import { Application } from "@hotwired/stimulus"
import ToggleController from "../../app/javascript/controllers/toggle_controller"

describe("ToggleController", () => {
  let application

  beforeEach(() => {
    application = Application.start()
    application.register("toggle", ToggleController)

    document.body.innerHTML = `
      <div data-controller="toggle">
        <button data-action="toggle#toggle">Toggle</button>
        <div data-toggle-target="toggleable" class="hidden">Content</div>
      </div>
    `
  })

  it("toggles visibility", () => {
    const button = document.querySelector("button")
    const content = document.querySelector("[data-toggle-target='toggleable']")

    expect(content.classList.contains("hidden")).toBe(true)

    button.click()

    expect(content.classList.contains("hidden")).toBe(false)
  })
})
```

## Stimulus naming conventions

### Controller names
- Kebab-case in HTML: `data-controller="auto-submit"`
- Snake_case in filename: `auto_submit_controller.js`
- PascalCase in class: `AutoSubmitController`

### Targets
- camelCase: `data-[controller]-target="menuItem"`
- Access: `this.menuItemTarget` or `this.menuItemTargets`

### Values
- camelCase: `data-[controller]-url-value="/path"`
- Access: `this.urlValue`

### Classes
- camelCase: `data-[controller]-active-class="is-active"`
- Access: `this.activeClass`

## Common Stimulus patterns catalog

### 1. Toggle class
```javascript
toggle() {
  this.element.classList.toggle(this.activeClass)
}
```

### 2. Show on hover
```javascript
show() {
  this.element.classList.remove(this.hiddenClass)
}

hide() {
  this.element.classList.add(this.hiddenClass)
}
```

### 3. Disable button on submit
```javascript
submit() {
  this.submitTarget.disabled = true
  this.element.requestSubmit()
}
```

### 4. Confirm action
```javascript
confirm(event) {
  if (!window.confirm("Are you sure?")) {
    event.preventDefault()
  }
}
```

### 5. Prevent default
```javascript
prevent(event) {
  event.preventDefault()
}
```

## Reusable controller library

The approach creates a library of generic controllers:

**UI controllers:**
- `toggle_controller` - Show/hide elements
- `dropdown_controller` - Dropdown menus
- `modal_controller` - Dialog boxes
- `tabs_controller` - Tab navigation
- `tooltip_controller` - Tooltips

**Form controllers:**
- `auto_submit_controller` - Auto-submit forms
- `character_counter_controller` - Character counting
- `form_validation_controller` - Validation UI
- `password_visibility_controller` - Show/hide password

**Utility controllers:**
- `clipboard_controller` - Copy to clipboard
- `auto_dismiss_controller` - Auto-remove elements
- `confirm_controller` - Confirmation dialogs
- `disable_controller` - Disable buttons

**Integration controllers:**
- `sortable_controller` - Drag and drop
- `trix_controller` - Rich text editor
- `flatpickr_controller` - Date picker

**Tracking controllers:**
- `beacon_controller` - Track events
- `visibility_controller` - Track visibility
- `scroll_controller` - Track scrolling

## Performance tips

### 1. Use event delegation
```javascript
connect() {
  // Good: One listener on parent
  this.element.addEventListener("click", this.#handleClick)
}

#handleClick(event) {
  if (event.target.matches(".delete-button")) {
    this.delete(event)
  }
}
```

### 2. Debounce expensive operations
```javascript
import { debounce } from "./helpers"

connect() {
  this.search = debounce(this.search.bind(this), 300)
}

search(event) {
  // Expensive operation
}
```

### 3. Clean up in disconnect
```javascript
disconnect() {
  clearTimeout(this.timeout)
  this.observer?.disconnect()
  document.removeEventListener("click", this.boundClose)
}
```

### 4. Use IntersectionObserver for visibility
```javascript
connect() {
  this.observer = new IntersectionObserver(this.#handleIntersection)
  this.observer.observe(this.element)
}
```

## Boundaries

- ✅ **Always do:** Keep controllers small (under 50 lines), single responsibility only, use values/classes for configuration, clean up in disconnect(), use private methods (#), provide fallback for no-JS, test with system tests, use event delegation
- ⚠️ **Ask first:** Before adding business logic (belongs in models), before fetching data (use Turbo), before managing complex state (server is source), before creating domain-specific controllers (favor generic + composition)
- 🚫 **Never do:** Build SPAs with Stimulus, put business logic in controllers, manage application state client-side, skip disconnect() cleanup, hardcode values (use data-values), create god controllers (split them), forget CSRF tokens in fetch requests, skip progressive enhancement (must work without JS)
