# Stimulus Reference

## Concept

Stimulus is a modest JavaScript framework for adding behavior to HTML. It connects JavaScript objects (controllers) to DOM elements using data attributes.

## Core Concepts

| Concept | Purpose | Attribute |
|---------|---------|-----------|
| Controller | JavaScript class | `data-controller="name"` |
| Action | Event handler | `data-action="event->controller#method"` |
| Target | DOM reference | `data-controller-target="name"` |
| Value | Reactive data | `data-controller-name-value="x"` |
| Class | CSS class reference | `data-controller-name-class="x"` |
| Outlet | Cross-controller reference | `data-controller-name-outlet=".selector"` |

## Basic Controller

```javascript
// app/javascript/controllers/hello_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["output"]

  greet() {
    this.outputTarget.textContent = "Hello, Stimulus!"
  }
}
```

```erb
<div data-controller="hello">
  <button data-action="click->hello#greet">Greet</button>
  <span data-hello-target="output"></span>
</div>
```

## Controller Lifecycle

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Called when controller connects to DOM
  connect() {
    console.log("Connected!", this.element)
  }

  // Called when controller disconnects
  disconnect() {
    console.log("Disconnected!")
  }

  // Called when target is added
  outputTargetConnected(element) {
    console.log("Target connected:", element)
  }

  // Called when target is removed
  outputTargetDisconnected(element) {
    console.log("Target disconnected:", element)
  }
}
```

## Targets

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output", "item"]

  // Single target (first match)
  copy() {
    this.outputTarget.textContent = this.inputTarget.value
  }

  // Multiple targets (all matches)
  clearAll() {
    this.itemTargets.forEach(el => el.remove())
  }

  // Check if target exists
  validate() {
    if (this.hasOutputTarget) {
      this.outputTarget.classList.add("validated")
    }
  }
}
```

```erb
<div data-controller="form">
  <input data-form-target="input" type="text">
  <div data-form-target="output"></div>
  <div data-form-target="item">Item 1</div>
  <div data-form-target="item">Item 2</div>
</div>
```

## Values

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String,
    count: { type: Number, default: 0 },
    enabled: Boolean,
    config: Object,
    items: Array
  }

  connect() {
    console.log(this.urlValue)      // String
    console.log(this.countValue)    // Number
    console.log(this.enabledValue)  // Boolean
  }

  // Called when value changes
  countValueChanged(value, previousValue) {
    console.log(`Count changed from ${previousValue} to ${value}`)
  }

  increment() {
    this.countValue++  // Triggers countValueChanged
  }
}
```

```erb
<div data-controller="counter"
     data-counter-url-value="/api/count"
     data-counter-count-value="5"
     data-counter-enabled-value="true"
     data-counter-config-value='{"max": 100}'>
</div>
```

## Actions

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // Basic action
  submit() {
    console.log("Submitted!")
  }

  // With event parameter
  handleClick(event) {
    event.preventDefault()
    console.log("Clicked:", event.target)
  }

  // With params
  delete(event) {
    const id = event.params.id
    console.log("Delete item:", id)
  }
}
```

```erb
<div data-controller="items">
  <%# Basic action %>
  <button data-action="click->items#submit">Submit</button>

  <%# Multiple events %>
  <input data-action="input->items#validate focus->items#highlight">

  <%# Shorthand (click is default for buttons) %>
  <button data-action="items#submit">Submit</button>

  <%# With params %>
  <button data-action="items#delete" data-items-id-param="123">Delete</button>

  <%# Prevent default %>
  <form data-action="submit->items#handleSubmit:prevent">

  <%# Stop propagation %>
  <button data-action="click->items#handle:stop">Click</button>
</div>
```

## Common Patterns

### Toggle Visibility

```javascript
// toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]
  static classes = ["hidden"]

  toggle() {
    this.contentTarget.classList.toggle(this.hiddenClass)
  }

  show() {
    this.contentTarget.classList.remove(this.hiddenClass)
  }

  hide() {
    this.contentTarget.classList.add(this.hiddenClass)
  }
}
```

```erb
<div data-controller="toggle" data-toggle-hidden-class="hidden">
  <button data-action="toggle#toggle">Toggle</button>
  <div data-toggle-target="content">Content here</div>
</div>
```

### Form Validation

```javascript
// validation_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "error", "submit"]

  validate() {
    const isValid = this.inputTarget.value.length >= 3

    this.errorTarget.textContent = isValid ? "" : "Minimum 3 characters"
    this.submitTarget.disabled = !isValid
  }
}
```

### Debounced Search

```javascript
// search_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "results"]
  static values = { url: String }

  search() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => {
      this.performSearch()
    }, 300)
  }

  async performSearch() {
    const query = this.inputTarget.value
    const response = await fetch(`${this.urlValue}?q=${query}`)
    this.resultsTarget.innerHTML = await response.text()
  }
}
```

### Clipboard

```javascript
// clipboard_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source"]
  static values = { successMessage: { type: String, default: "Copied!" } }

  copy() {
    navigator.clipboard.writeText(this.sourceTarget.value)
    this.showNotification()
  }

  showNotification() {
    // Show temporary feedback
  }
}
```

## File Naming

```
app/javascript/controllers/
├── application.js           # Auto-generated
├── index.js                 # Auto-generated
├── hello_controller.js      # data-controller="hello"
├── clipboard_controller.js  # data-controller="clipboard"
└── nested/
    └── form_controller.js   # data-controller="nested--form"
```

## Debugging

```javascript
// Enable debug mode
import { Application } from "@hotwired/stimulus"
const application = Application.start()
application.debug = true  // Logs controller lifecycle
```
