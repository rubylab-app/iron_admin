import { Controller } from "@hotwired/stimulus"

// Controls the off-canvas sidebar drawer on small viewports.
// On large screens the sidebar is statically positioned and these
// actions are effectively no-ops (Tailwind `lg:` variants keep it visible).
export default class extends Controller {
  static targets = ["panel", "backdrop"]

  open() {
    this.panelTarget.classList.remove("-translate-x-full")
    if (this.hasBackdropTarget) this.backdropTarget.classList.remove("hidden")
  }

  close() {
    this.panelTarget.classList.add("-translate-x-full")
    if (this.hasBackdropTarget) this.backdropTarget.classList.add("hidden")
  }

  toggle() {
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
