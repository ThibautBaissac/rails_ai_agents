# Controller Catalog

## UI Controllers

### Toggle controller (show/hide elements)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggleable"]
  static classes = ["hidden"]

  toggle() {
    this.toggleableTargets.forEach(el => el.classList.toggle(this.hiddenClass))
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
  <button data-action="toggle#toggle">Toggle Details</button>
  <div data-toggle-target="toggleable" class="hidden">
    <p>Details content...</p>
  </div>
</div>
```

### Modal controller (dialog boxes)

```javascript
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

  clickOutside(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  closeWithKeyboard(event) {
    if (event.key === "Escape") this.close()
  }
}
```

```erb
<div data-controller="modal">
  <button data-action="modal#open">Open Modal</button>
  <dialog data-modal-target="dialog"
          data-action="click->modal#clickOutside keydown->modal#closeWithKeyboard">
    <div class="modal__content">
      <h2>Modal Title</h2>
      <p>Content...</p>
      <button data-action="modal#close">Close</button>
    </div>
  </dialog>
</div>
```

### Dropdown controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu"]
  static classes = ["open"]

  connect() { this.boundClose = this.close.bind(this) }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.classList.contains(this.openClass) ? this.close() : this.open()
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
<div data-controller="dropdown">
  <button data-action="dropdown#toggle">Menu</button>
  <div data-dropdown-target="menu" class="dropdown-menu">
    <%= link_to "Edit", edit_card_path(@card) %>
    <%= link_to "Delete", card_path(@card), method: :delete %>
  </div>
</div>
```

### Auto-dismiss controller (flash messages)

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 5000 } }

  connect() {
    this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
  }

  disconnect() { clearTimeout(this.timeout) }

  dismiss() { this.element.remove() }
}
```

```erb
<div class="flash flash--notice"
     data-controller="auto-dismiss"
     data-auto-dismiss-delay-value="3000">
  <%= message %>
  <button data-action="auto-dismiss#dismiss">x</button>
</div>
```

## Form Controllers

### Auto-submit controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: { type: Number, default: 300 } }

  submit() {
    clearTimeout(this.timeout)
    this.timeout = setTimeout(() => this.element.requestSubmit(), this.delayValue)
  }

  disconnect() { clearTimeout(this.timeout) }
}
```

```erb
<%= form_with model: @filter,
    data: { controller: "auto-submit", action: "change->auto-submit#submit" } do |f| %>
  <%= f.select :status, Card.statuses.keys %>
<% end %>
```

### Character counter controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "count"]
  static values = { max: Number }

  connect() { this.update() }

  update() {
    const remaining = this.maxValue - this.inputTarget.value.length
    this.countTarget.textContent = `${remaining} characters remaining`
    this.countTarget.classList.toggle("text-danger", remaining < 0)
  }
}
```

```erb
<div data-controller="character-counter" data-character-counter-max-value="280">
  <%= f.text_area :body,
      data: { character_counter_target: "input", action: "input->character-counter#update" } %>
  <div data-character-counter-target="count"></div>
</div>
```

### Form validation UI controller

```javascript
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input"]

  validate(event) {
    const input = event.target
    input.validity.valid ? this.#markValid(input) : this.#markInvalid(input)
  }

  #markValid(input) {
    input.classList.replace("input--invalid", "input--valid")
    input.parentElement.querySelector(".error-message")?.remove()
  }

  #markInvalid(input) {
    input.classList.replace("input--valid", "input--invalid")
    const error = input.parentElement.querySelector(".error-message")
      || Object.assign(document.createElement("div"), { className: "error-message" })
    error.textContent = input.validationMessage
    input.parentElement.appendChild(error)
  }
}
```

## Utility Controllers

### Clipboard controller

```javascript
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

    navigator.clipboard.writeText(text).then(() => this.#showSuccess())
  }

  #showSuccess() {
    const original = this.buttonTarget.textContent
    this.buttonTarget.textContent = this.successMessageValue
    setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
  }
}
```

```erb
<div data-controller="clipboard" data-clipboard-content-value="<%= @card.public_url %>">
  <input data-clipboard-target="source" value="<%= @card.public_url %>" readonly>
  <button data-action="clipboard#copy" data-clipboard-target="button">Copy</button>
</div>
```
