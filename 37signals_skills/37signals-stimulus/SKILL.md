---
name: 37signals-stimulus
description: Build focused, single-purpose Stimulus controllers for progressive enhancement. Triggers on Stimulus, JavaScript, controller, toggle, modal, dropdown.
allowed-tools: Read, Write, Edit, Bash
---

# 37signals Stimulus Skill

## Overview

Build small, single-purpose Stimulus controllers (most under 50 lines). Use Stimulus for progressive enhancement, not application logic.

## Core Philosophy

- **Stimulus for sprinkles**: DOM manipulation, UI interactions
- **Not for SPAs**: No client-side routing or state management
- **Single responsibility**: One controller, one purpose
- **Progressive enhancement**: Must work without JavaScript

## Controller Template

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "output"]
  static classes = ["active", "hidden"]
  static values = {
    url: String,
    timeout: { type: Number, default: 5000 }
  }

  connect() {
    console.log("Connected", this.element)
  }

  disconnect() {
    // Cleanup
  }

  toggle(event) {
    event.preventDefault()
    this.element.classList.toggle(this.activeClass)
  }
}
```

## Reusable Controllers

### Toggle Controller

```javascript
// app/javascript/controllers/toggle_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleable"]
  static classes = ["hidden"]

  toggle() {
    this.toggleableTargets.forEach(el => {
      el.classList.toggle(this.hiddenClass)
    })
  }

  show() {
    this.toggleableTargets.forEach(el => el.classList.remove(this.hiddenClass))
  }

  hide() {
    this.toggleableTargets.forEach(el => el.classList.add(this.hiddenClass))
  }
}
```

```erb
<div data-controller="toggle">
  <button data-action="toggle#toggle">Toggle</button>
  <div data-toggle-target="toggleable" class="hidden">Content</div>
</div>
```

### Dropdown Controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static classes = ["open"]

  connect() {
    this.boundClose = this.close.bind(this)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.toggle(this.openClass)

    if (this.menuTarget.classList.contains(this.openClass)) {
      document.addEventListener("click", this.boundClose)
    }
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

### Modal Controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog"]

  open(event) {
    event?.preventDefault()
    this.dialogTarget.showModal()
  }

  close(event) {
    event?.preventDefault()
    this.dialogTarget.close()
  }

  clickOutside(event) {
    if (event.target === this.dialogTarget) this.close()
  }
}
```

### Clipboard Controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["source", "button"]
  static values = { content: String, successMessage: { type: String, default: "Copied!" } }

  copy(event) {
    event.preventDefault()
    const text = this.hasContentValue ? this.contentValue : this.sourceTarget.value

    navigator.clipboard.writeText(text).then(() => {
      const original = this.buttonTarget.textContent
      this.buttonTarget.textContent = this.successMessageValue
      setTimeout(() => this.buttonTarget.textContent = original, 2000)
    })
  }
}
```

### Auto-Submit Controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

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
<%= form_with model: @filter,
    data: { controller: "auto-submit", action: "change->auto-submit#submit" } do |f| %>
  <%= f.select :status, statuses %>
<% end %>
```

### Auto-Dismiss Controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  dismiss() {
    this.element.remove()
  }
}
```

### Character Counter Controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }

  connect() {
    this.update()
  }

  update() {
    const remaining = this.maxValue - this.inputTarget.value.length
    this.countTarget.textContent = `${remaining} characters remaining`
    this.countTarget.classList.toggle("text-danger", remaining < 0)
  }
}
```

## Integration Controllers

### Sortable (Drag & Drop)

```javascript
import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      onEnd: this.end.bind(this)
    })
  }

  end(event) {
    fetch(this.urlValue, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json', 'X-CSRF-Token': this.csrfToken },
      body: JSON.stringify({ id: event.item.dataset.id, position: event.newIndex })
    })
  }

  get csrfToken() {
    return document.querySelector('meta[name="csrf-token"]').content
  }

  disconnect() {
    this.sortable?.destroy()
  }
}
```

## Naming Conventions

- **Controller names**: Kebab-case in HTML (`data-controller="auto-submit"`)
- **Filenames**: Snake_case (`auto_submit_controller.js`)
- **Targets**: camelCase (`data-[controller]-target="menuItem"`)
- **Values**: camelCase (`data-[controller]-url-value="/path"`)

## Performance Tips

1. **Clean up in disconnect()**: Clear timeouts, remove listeners
2. **Use event delegation**: One listener on parent, not many on children
3. **Debounce expensive operations**: Don't run on every keystroke

## Boundaries

### Always
- Keep controllers small (under 50 lines)
- Single responsibility
- Use values/classes for configuration
- Clean up in disconnect()
- Provide no-JS fallback

### Never
- Build SPAs with Stimulus
- Put business logic in controllers
- Manage application state client-side
- Hardcode values (use data-values)
- Skip progressive enhancement
