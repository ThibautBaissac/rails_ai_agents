# Stimulus Controller Patterns Reference

## 1. Toggle Controller

```javascript
import { Controller } from "@hotwired/stimulus"

/**
 * Toggle Controller
 *
 * Simple toggle for showing/hiding content with accessibility support.
 *
 * Targets:
 * - content: The element to show/hide
 * - trigger: The button that toggles visibility
 *
 * Values:
 * - open: Whether the content is currently visible (default: false)
 *
 * @example
 * <div data-controller="toggle">
 *   <button data-toggle-target="trigger"
 *           data-action="toggle#toggle"
 *           aria-expanded="false"
 *           aria-controls="content">
 *     Toggle
 *   </button>
 *   <div id="content"
 *        data-toggle-target="content"
 *        class="hidden">
 *     Hidden content
 *   </div>
 * </div>
 */
export default class extends Controller {
  static targets = ["content", "trigger"]
  static values = {
    open: { type: Boolean, default: false }
  }

  toggle(event) {
    event?.preventDefault()
    this.openValue = !this.openValue
  }

  open() {
    this.openValue = true
  }

  close() {
    this.openValue = false
  }

  openValueChanged(isOpen) {
    this.contentTarget.classList.toggle("hidden", !isOpen)

    if (this.hasTriggerTarget) {
      this.triggerTarget.setAttribute("aria-expanded", isOpen.toString())
    }

    this.dispatch(isOpen ? "opened" : "closed")
  }
}
```

## 2. Form Validation Controller

```javascript
import { Controller } from "@hotwired/stimulus"

/**
 * Form Validation Controller
 *
 * Handles client-side form validation with real-time feedback.
 *
 * Targets:
 * - form: The form element
 * - input: Input fields to validate
 * - error: Error message containers
 * - submit: Submit button to enable/disable
 *
 * Values:
 * - valid: Whether the form is currently valid
 *
 * @example
 * <form data-controller="form-validation"
 *       data-form-validation-target="form"
 *       data-action="submit->form-validation#validate">
 *   <input data-form-validation-target="input"
 *          data-action="blur->form-validation#validateField"
 *          required>
 *   <span data-form-validation-target="error" class="hidden"></span>
 *   <button data-form-validation-target="submit">Submit</button>
 * </form>
 */
export default class extends Controller {
  static targets = ["form", "input", "error", "submit"]
  static values = {
    valid: { type: Boolean, default: true }
  }

  connect() {
    this.validateForm()
  }

  validate(event) {
    if (!this.validateForm()) {
      event.preventDefault()
    }
  }

  validateField(event) {
    const input = event.target
    const isValid = input.checkValidity()
    this.#showFieldError(input, isValid)
    this.validateForm()
  }

  validateForm() {
    const isValid = this.inputTargets.every(input => input.checkValidity())
    this.validValue = isValid

    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = !isValid
    }

    return isValid
  }

  #showFieldError(input, isValid) {
    const errorTarget = this.errorTargets.find(
      error => error.dataset.field === input.name
    )

    if (errorTarget) {
      errorTarget.textContent = isValid ? "" : input.validationMessage
      errorTarget.classList.toggle("hidden", isValid)
    }

    input.setAttribute("aria-invalid", (!isValid).toString())
  }
}
```

## 3. Search with Debounce Controller

```javascript
import { Controller } from "@hotwired/stimulus"

/**
 * Search Controller
 *
 * Handles search input with debouncing for performance.
 *
 * Targets:
 * - input: The search input field
 * - results: Container for search results
 * - loading: Loading indicator
 *
 * Values:
 * - url: The search endpoint URL
 * - debounce: Debounce delay in milliseconds (default: 300)
 * - minLength: Minimum query length to trigger search (default: 2)
 *
 * @example
 * <div data-controller="search"
 *      data-search-url-value="/search"
 *      data-search-debounce-value="300">
 *   <input data-search-target="input"
 *          data-action="input->search#search"
 *          placeholder="Search...">
 *   <div data-search-target="loading" class="hidden">Loading...</div>
 *   <div data-search-target="results"></div>
 * </div>
 */
export default class extends Controller {
  static targets = ["input", "results", "loading"]
  static values = {
    url: String,
    debounce: { type: Number, default: 300 },
    minLength: { type: Number, default: 2 }
  }

  connect() {
    this.timeout = null
    this.abortController = null
  }

  disconnect() {
    this.#clearTimeout()
    this.#abortRequest()
  }

  search() {
    this.#clearTimeout()

    const query = this.inputTarget.value.trim()

    if (query.length < this.minLengthValue) {
      this.#clearResults()
      return
    }

    this.timeout = setTimeout(() => {
      this.#performSearch(query)
    }, this.debounceValue)
  }

  async #performSearch(query) {
    this.#abortRequest()
    this.abortController = new AbortController()

    this.#showLoading()

    try {
      const url = new URL(this.urlValue, window.location.origin)
      url.searchParams.set("q", query)

      const response = await fetch(url, {
        signal: this.abortController.signal,
        headers: {
          "Accept": "text/vnd.turbo-stream.html, text/html"
        }
      })

      if (response.ok) {
        const html = await response.text()
        this.resultsTarget.innerHTML = html
        this.dispatch("results", { detail: { query, results: html } })
      }
    } catch (error) {
      if (error.name !== "AbortError") {
        console.error("Search failed:", error)
        this.dispatch("error", { detail: { error } })
      }
    } finally {
      this.#hideLoading()
    }
  }

  #clearTimeout() {
    if (this.timeout) {
      clearTimeout(this.timeout)
      this.timeout = null
    }
  }

  #abortRequest() {
    if (this.abortController) {
      this.abortController.abort()
      this.abortController = null
    }
  }

  #showLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.remove("hidden")
    }
  }

  #hideLoading() {
    if (this.hasLoadingTarget) {
      this.loadingTarget.classList.add("hidden")
    }
  }

  #clearResults() {
    this.resultsTarget.innerHTML = ""
  }
}
```

## 4. Keyboard Navigation Controller

```javascript
import { Controller } from "@hotwired/stimulus"

/**
 * Keyboard Navigation Controller
 *
 * Adds keyboard navigation to a list of items.
 *
 * Targets:
 * - item: Navigable items
 *
 * Values:
 * - wrap: Whether to wrap around at ends (default: true)
 * - orientation: "vertical" or "horizontal" (default: "vertical")
 *
 * @example
 * <ul data-controller="keyboard-nav"
 *     data-action="keydown->keyboard-nav#navigate"
 *     role="listbox"
 *     tabindex="0">
 *   <li data-keyboard-nav-target="item" role="option">Item 1</li>
 *   <li data-keyboard-nav-target="item" role="option">Item 2</li>
 * </ul>
 */
export default class extends Controller {
  static targets = ["item"]
  static values = {
    wrap: { type: Boolean, default: true },
    orientation: { type: String, default: "vertical" }
  }

  connect() {
    this.currentIndex = -1
  }

  navigate(event) {
    const isVertical = this.orientationValue === "vertical"
    const nextKey = isVertical ? "ArrowDown" : "ArrowRight"
    const prevKey = isVertical ? "ArrowUp" : "ArrowLeft"

    switch (event.key) {
      case nextKey:
        event.preventDefault()
        this.#focusNext()
        break

      case prevKey:
        event.preventDefault()
        this.#focusPrevious()
        break

      case "Home":
        event.preventDefault()
        this.#focusFirst()
        break

      case "End":
        event.preventDefault()
        this.#focusLast()
        break

      case "Enter":
      case " ":
        event.preventDefault()
        this.#selectCurrent()
        break
    }
  }

  #focusNext() {
    const items = this.itemTargets
    if (items.length === 0) return

    if (this.currentIndex < items.length - 1) {
      this.currentIndex++
    } else if (this.wrapValue) {
      this.currentIndex = 0
    }

    this.#focusItem(this.currentIndex)
  }

  #focusPrevious() {
    const items = this.itemTargets
    if (items.length === 0) return

    if (this.currentIndex > 0) {
      this.currentIndex--
    } else if (this.wrapValue) {
      this.currentIndex = items.length - 1
    }

    this.#focusItem(this.currentIndex)
  }

  #focusFirst() {
    this.currentIndex = 0
    this.#focusItem(0)
  }

  #focusLast() {
    this.currentIndex = this.itemTargets.length - 1
    this.#focusItem(this.currentIndex)
  }

  #focusItem(index) {
    const items = this.itemTargets

    items.forEach((item, i) => {
      item.setAttribute("aria-selected", (i === index).toString())
      item.classList.toggle("bg-gray-100", i === index)
    })

    if (items[index]) {
      items[index].focus()
      this.dispatch("focus", { detail: { index, item: items[index] } })
    }
  }

  #selectCurrent() {
    if (this.currentIndex >= 0 && this.itemTargets[this.currentIndex]) {
      const item = this.itemTargets[this.currentIndex]
      this.dispatch("select", { detail: { index: this.currentIndex, item } })
    }
  }
}
```

## 5. Auto-submit Form Controller

```javascript
import { Controller } from "@hotwired/stimulus"

/**
 * Auto Submit Controller
 *
 * Automatically submits a form when inputs change.
 *
 * Values:
 * - delay: Debounce delay in milliseconds (default: 150)
 *
 * @example
 * <form data-controller="auto-submit"
 *       data-auto-submit-delay-value="300"
 *       data-turbo-frame="results">
 *   <select data-action="change->auto-submit#submit">
 *     <option>Option 1</option>
 *     <option>Option 2</option>
 *   </select>
 *   <input data-action="input->auto-submit#submit" type="text">
 * </form>
 */
export default class extends Controller {
  static values = {
    delay: { type: Number, default: 150 }
  }

  connect() {
    this.timeout = null
  }

  disconnect() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }
  }

  submit() {
    if (this.timeout) {
      clearTimeout(this.timeout)
    }

    this.timeout = setTimeout(() => {
      this.element.requestSubmit()
    }, this.delayValue)
  }
}
```
