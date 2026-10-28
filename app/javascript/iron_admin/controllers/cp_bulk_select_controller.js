import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "count", "selectAll", "checkbox"]

  toggleAll() {
    const checked = this.selectAllTarget.checked
    this.checkboxTargets.forEach((cb) => { cb.checked = checked })
    this.updateBar()
  }

  toggle() {
    const total = this.checkboxTargets.length
    const checked = this.checkboxTargets.filter((cb) => cb.checked).length
    this.selectAllTarget.checked = checked === total && total > 0
    this.updateBar()
  }

  updateBar() {
    const checked = this.checkboxTargets.filter((cb) => cb.checked).length
    this.barTarget.style.display = checked > 0 ? "flex" : "none"
    this.countTarget.textContent = checked
  }

  // A bulk action with form fields submits the selection with a GET (formmethod="get"), whose
  // URL would carry the form's CSRF token. The token is disabled while the browser, or Turbo,
  // reads the form, and enabled again for the next POST.
  omitTokenFromGet(event) {
    if (event.submitter?.getAttribute("formmethod")?.toLowerCase() !== "get") return

    const param = document.querySelector("meta[name='csrf-param']")?.content || "authenticity_token"
    const tokens = [...this.element.elements].filter((input) => input.name === param && !input.disabled)
    tokens.forEach((input) => { input.disabled = true })
    setTimeout(() => tokens.forEach((input) => { input.disabled = false }))
  }
}
