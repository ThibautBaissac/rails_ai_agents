# Stimulus Examples

## Integration Controllers

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

  disconnect() { this.sortable?.destroy() }

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
<div data-controller="sortable" data-sortable-url-value="<%= reorder_cards_path %>">
  <% @cards.each do |card| %>
    <div data-id="<%= card.id %>"><%= render card %></div>
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

  #preventFileUploads(event) {
    event.preventDefault()
    alert("Please use the attachment button to upload files")
  }

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

## Tracking Controllers

### Beacon controller (track views after delay)

```javascript
// app/javascript/controllers/beacon_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    delay: { type: Number, default: 3000 }
  }

  connect() {
    this.timeout = setTimeout(() => this.#send(), this.delayValue)
  }

  disconnect() { clearTimeout(this.timeout) }

  #send() {
    if (!this.hasUrlValue) return
    navigator.sendBeacon(this.urlValue, JSON.stringify({
      timestamp: new Date().toISOString()
    }))
  }
}
```

```erb
<div data-controller="beacon" data-beacon-url-value="<%= card_reading_path(@card) %>">
  <%= render @card %>
</div>
```

### Visibility tracker (IntersectionObserver)

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

  disconnect() { this.observer?.disconnect() }

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
      headers: { 'X-CSRF-Token': this.#csrfToken }
    })
  }

  get #csrfToken() {
    return document.querySelector('meta[name="csrf-token"]')?.content
  }
}
```

## Animation Controllers

### Slide-down controller (animate new items)

```javascript
// app/javascript/controllers/slide_down_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 300 } }

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
<%= turbo_stream.prepend "comments" do %>
  <div data-controller="slide-down"><%= render @comment %></div>
<% end %>
```

### Fade-in controller

```javascript
// app/javascript/controllers/fade_in_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { duration: { type: Number, default: 300 } }

  connect() {
    this.element.style.opacity = "0"
    this.element.style.transition = `opacity ${this.durationValue}ms ease-in`
    requestAnimationFrame(() => { this.element.style.opacity = "1" })
  }
}
```

## Domain-Specific Controllers

### Card drag-and-drop controller

```javascript
// app/javascript/controllers/card_drag_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  dragStart(event) {
    event.dataTransfer.effectAllowed = "move"
    event.dataTransfer.setData("text/plain", event.target.dataset.cardId)
    event.target.classList.add("dragging")
  }

  dragEnd(event) { event.target.classList.remove("dragging") }

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
        'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]')?.content
      },
      body: JSON.stringify({ column_id: columnId })
    })
  }
}
```

### Filter controller (client-side search)

```javascript
// app/javascript/controllers/filter_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["item"]
  static values = { query: String }

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
      item.hidden = !item.textContent.toLowerCase().includes(this.queryValue)
    })
  }
}
```

```erb
<div data-controller="filter">
  <input type="search" placeholder="Filter cards..."
         data-action="input->filter#filter">
  <% @cards.each do |card| %>
    <div data-filter-target="item"><%= card.title %></div>
  <% end %>
</div>
```

## Common micro-patterns

```javascript
// Toggle class
toggle() { this.element.classList.toggle(this.activeClass) }

// Disable button on submit
submit() { this.submitTarget.disabled = true; this.element.requestSubmit() }

// Confirm action
confirm(event) { if (!window.confirm("Are you sure?")) event.preventDefault() }

// Prevent default
prevent(event) { event.preventDefault() }
```

## JavaScript tests (optional)

```javascript
import { Application } from "@hotwired/stimulus"
import ToggleController from "../../app/javascript/controllers/toggle_controller"

describe("ToggleController", () => {
  beforeEach(() => {
    const app = Application.start()
    app.register("toggle", ToggleController)
    document.body.innerHTML = `
      <div data-controller="toggle">
        <button data-action="toggle#toggle">Toggle</button>
        <div data-toggle-target="toggleable" class="hidden">Content</div>
      </div>
    `
  })

  it("toggles visibility", () => {
    const content = document.querySelector("[data-toggle-target='toggleable']")
    expect(content.classList.contains("hidden")).toBe(true)
    document.querySelector("button").click()
    expect(content.classList.contains("hidden")).toBe(false)
  })
})
```
