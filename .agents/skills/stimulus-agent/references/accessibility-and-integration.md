# Stimulus Accessibility and Integration Reference

## Accessibility Best Practices

### ARIA Attributes

```javascript
// ✅ GOOD - Proper ARIA usage
open() {
  this.menuTarget.classList.remove("hidden")
  this.triggerTarget.setAttribute("aria-expanded", "true")
  this.menuTarget.setAttribute("aria-hidden", "false")
  this.triggerTarget.setAttribute("aria-controls", this.menuTarget.id)
}

close() {
  this.menuTarget.classList.add("hidden")
  this.triggerTarget.setAttribute("aria-expanded", "false")
  this.menuTarget.setAttribute("aria-hidden", "true")
}

// ✅ GOOD - Screen reader announcements
announce(message) {
  if (this.hasAnnouncementTarget) {
    this.announcementTarget.textContent = message
  }
}
```

### Focus Management

```javascript
// ✅ GOOD - Trap focus in modals
trapFocus() {
  const focusableElements = this.element.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  )

  this.firstFocusable = focusableElements[0]
  this.lastFocusable = focusableElements[focusableElements.length - 1]
}

handleTab(event) {
  if (event.key !== "Tab") return

  if (event.shiftKey && document.activeElement === this.firstFocusable) {
    event.preventDefault()
    this.lastFocusable.focus()
  } else if (!event.shiftKey && document.activeElement === this.lastFocusable) {
    event.preventDefault()
    this.firstFocusable.focus()
  }
}
```

## Integration with Turbo

### Turbo Frame Integration

```javascript
/**
 * Frame Controller
 *
 * Handles Turbo Frame loading states.
 */
export default class extends Controller {
  static targets = ["frame", "loading"]

  connect() {
    this.frameTarget.addEventListener("turbo:frame-load", this.#onLoad.bind(this))
    this.frameTarget.addEventListener("turbo:frame-render", this.#onRender.bind(this))
  }

  disconnect() {
    this.frameTarget.removeEventListener("turbo:frame-load", this.#onLoad)
    this.frameTarget.removeEventListener("turbo:frame-render", this.#onRender)
  }

  #onLoad() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }

  #onRender() {
    this.dispatch("rendered")
  }
}
```

### Flash Controller (Turbo Stream Events)

```javascript
/**
 * Flash Controller
 *
 * Auto-dismisses flash messages delivered via Turbo Streams.
 */
export default class extends Controller {
  static values = {
    autoDismiss: { type: Boolean, default: true },
    delay: { type: Number, default: 5000 }
  }

  connect() {
    if (this.autoDismissValue) {
      this.timeout = setTimeout(() => this.dismiss(), this.delayValue)
    }
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  dismiss() {
    this.element.classList.add("animate-fade-out")
    this.element.addEventListener("animationend", () => {
      this.element.remove()
    })
  }
}
```

## Integration with ViewComponents

### Component with Stimulus Controller

```ruby
# app/components/dropdown_component.rb
class DropdownComponent < ViewComponent::Base
  def initialize(id:, **html_attributes)
    @id = id
    @html_attributes = html_attributes
  end

  def stimulus_attributes
    {
      controller: "components--dropdown",
      "components--dropdown-open-value": false,
      "components--dropdown-close-on-select-value": true
    }
  end
end
```

```erb
<%# app/components/dropdown_component.html.erb %>
<div id="<%= @id %>"
     <%= tag.attributes(stimulus_attributes.merge(@html_attributes)) %>>
  <button data-action="components--dropdown#toggle"
          data-components--dropdown-target="trigger"
          aria-expanded="false"
          aria-haspopup="true">
    <%= trigger %>
  </button>

  <div data-components--dropdown-target="menu"
       class="hidden"
       role="menu">
    <%= content %>
  </div>
</div>
```

## Event Dispatching

```javascript
// Dispatch custom events for parent controllers or other listeners
this.dispatch("select", {
  detail: { item: selectedItem, value: selectedValue },
  bubbles: true,
  cancelable: true
})

// Listen in HTML
// <div data-action="child-controller:select->parent-controller#handleSelect">
```

## Testing Stimulus in Component Specs

```ruby
# spec/components/dropdown_component_spec.rb
RSpec.describe DropdownComponent, type: :component do
  it "applies Stimulus controller" do
    render_inline(DropdownComponent.new(id: "dropdown"))

    expect(page).to have_css('[data-controller="components--dropdown"]')
  end

  it "sets default values" do
    render_inline(DropdownComponent.new(id: "dropdown"))

    expect(page).to have_css('[data-components--dropdown-open-value="false"]')
  end

  it "has trigger target" do
    render_inline(DropdownComponent.new(id: "dropdown"))

    expect(page).to have_css('[data-components--dropdown-target="trigger"]')
  end

  it "has proper ARIA attributes on trigger" do
    render_inline(DropdownComponent.new(id: "dropdown"))

    trigger = page.find('[data-components--dropdown-target="trigger"]')
    expect(trigger["aria-expanded"]).to eq("false")
    expect(trigger["aria-haspopup"]).to eq("true")
  end
end
```

## What NOT to Do

```javascript
// ❌ BAD - Using jQuery
$(this.element).hide()

// ✅ GOOD - Use native DOM
this.element.classList.add("hidden")

// ❌ BAD - Querying outside controller scope
document.querySelectorAll(".some-class")

// ✅ GOOD - Use targets within controller scope
this.itemTargets

// ❌ BAD - Not cleaning up event listeners
connect() {
  document.addEventListener("click", this.handleClick)
}
// Memory leak! No disconnect cleanup

// ✅ GOOD - Proper cleanup
connect() {
  this.boundHandleClick = this.handleClick.bind(this)
  document.addEventListener("click", this.boundHandleClick)
}

disconnect() {
  document.removeEventListener("click", this.boundHandleClick)
}

// ❌ BAD - Storing state in the DOM unnecessarily
this.element.dataset.isOpen = "true"

// ✅ GOOD - Use Stimulus values
this.openValue = true

// ❌ BAD - Inline styles
this.element.style.display = "none"

// ✅ GOOD - Toggle classes (works with Tailwind)
this.element.classList.add("hidden")

// ❌ BAD - Ignoring accessibility
toggle() {
  this.menuTarget.classList.toggle("hidden")
}

// ✅ GOOD - Include accessibility
toggle() {
  const isOpen = !this.openValue
  this.openValue = isOpen
  this.menuTarget.classList.toggle("hidden", !isOpen)
  this.triggerTarget.setAttribute("aria-expanded", isOpen.toString())
}
```
