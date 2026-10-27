import { Controller } from "@hotwired/stimulus"

// Focuses and selects the navbar search box on ⌘K (Apple platforms) or Ctrl+K
// (elsewhere), wherever the focus is, but never while a modal dialog is open or
// the search box is inert (behind the open sidebar drawer). On connect it shows
// the platform's shortcut in the hint, which stays hidden without JavaScript.
export default class extends Controller {
  static targets = ["input", "hint"]

  connect() {
    const platform = navigator.userAgentData?.platform || navigator.platform || ""
    this.apple = /mac|iphone|ipad|ipod/i.test(platform)
    if (this.hasInputTarget) this.inputTarget.setAttribute("aria-keyshortcuts", this.apple ? "Meta+K" : "Control+K")
    if (this.hasHintTarget) {
      this.hintTarget.textContent = this.apple ? "⌘K" : "Ctrl K"
      this.hintTarget.hidden = false
    }
  }

  focus(event) {
    if (!this.isShortcut(event) || !this.hasInputTarget || this.isBlocked) return

    event.preventDefault()
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  isShortcut(event) {
    const modifier = this.apple ? event.metaKey && !event.ctrlKey : event.ctrlKey && !event.metaKey
    return modifier && !event.altKey && !event.shiftKey && event.key?.toLowerCase() === "k"
  }

  get isBlocked() {
    if (this.inputTarget.closest("[inert]")) return true

    return Array.from(document.querySelectorAll("[aria-modal='true'], dialog:modal"))
      .some((dialog) => (dialog.checkVisibility ? dialog.checkVisibility() : true))
  }
}
