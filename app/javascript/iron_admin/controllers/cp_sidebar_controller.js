import { Controller } from "@hotwired/stimulus"

// Controls the off-canvas sidebar drawer on small viewports.
// On large screens the sidebar is statically positioned and these
// actions are effectively no-ops (Tailwind `lg:` variants keep it visible).
export default class extends Controller {
  static targets = ["panel", "backdrop", "toggle"]

  open() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.remove("-translate-x-full")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.add("-translate-x-full")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
  }

  toggle() {
    if (!this.hasPanelTarget) return
    if (this.panelTarget.classList.contains("-translate-x-full")) {
      this.open()
    } else {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
