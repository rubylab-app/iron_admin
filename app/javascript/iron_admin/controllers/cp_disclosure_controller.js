import { Controller } from "@hotwired/stimulus"

// Closes a <details> disclosure on Escape (focus returns to its summary) and on
// a click outside it. Opening, Tab and Enter/Space are the browser's own.
export default class extends Controller {
  static targets = ["summary"]

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.element.open) return

    event.preventDefault()
    this.element.open = false
    if (this.hasSummaryTarget) this.summaryTarget.focus()
  }

  closeOnOutsideClick(event) {
    if (this.element.open && !this.element.contains(event.target)) this.element.open = false
  }
}
