import { Controller } from "@hotwired/stimulus"

// Off-canvas sidebar drawer below `lg`. Closed, the panel is inert; open, the
// `content` targets are inert, so Tab stays in the drawer. From `lg` up nothing
// is inert, and crossing the breakpoint resets the drawer to closed.
export default class extends Controller {
  static targets = ["panel", "backdrop", "toggle", "closeButton", "content"]

  connect() {
    // Tailwind's `lg` breakpoint.
    this.largeScreen = window.matchMedia("(min-width: 64rem)")
    this.reset = () => this.render(false)
    this.largeScreen.addEventListener("change", this.reset)
    // Also undoes an open drawer restored from a Turbo cache snapshot.
    this.render(false)
  }

  disconnect() {
    this.largeScreen.removeEventListener("change", this.reset)
  }

  open() {
    if (!this.hasPanelTarget) return
    this.render(true)
    const focusTarget = this.hasCloseButtonTarget ? this.closeButtonTarget : this.panelTarget.querySelector("a[href], button")
    focusTarget?.focus()
  }

  close() {
    if (!this.hasPanelTarget) return
    this.render(false)
    if (this.hasToggleTarget) this.toggleTarget.focus()
  }

  toggle() {
    if (this.isOpen) {
      this.close()
    } else {
      this.open()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.isOpen) this.close()
  }

  get isOpen() {
    return this.hasPanelTarget && !this.panelTarget.classList.contains("-translate-x-full")
  }

  render(open) {
    if (!this.hasPanelTarget) return
    const drawer = !this.largeScreen.matches
    this.panelTarget.classList.toggle("-translate-x-full", !open)
    this.panelTarget.inert = drawer && !open
    this.backdropTargets.forEach((backdrop) => backdrop.classList.toggle("hidden", !open))
    this.contentTargets.forEach((element) => { element.inert = drawer && open })
    this.toggleTargets.forEach((toggle) => toggle.setAttribute("aria-expanded", String(open)))
  }
}
