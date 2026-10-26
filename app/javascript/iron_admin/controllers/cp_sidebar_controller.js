import { Controller } from "@hotwired/stimulus"

// Off-canvas sidebar drawer while the panel is `fixed` (below the host's `lg`).
// Closed, the drawer is inert; open, the `content` targets are inert, so Tab
// stays in it. Otherwise nothing is inert; switching modes closes the drawer.
export default class extends Controller {
  static targets = ["panel", "backdrop", "toggle", "closeButton", "content"]

  connect() {
    this.drawer = this.isDrawer
    this.reset = () => {
      const drawer = this.isDrawer
      if (drawer === this.drawer) return
      this.drawer = drawer
      this.render(false)
    }
    window.addEventListener("resize", this.reset)
    // Also undoes an open drawer restored from a Turbo cache snapshot.
    this.render(false)
  }

  disconnect() {
    window.removeEventListener("resize", this.reset)
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

  // Read from the compiled CSS (`fixed … lg:static`), not a fixed width, so a
  // host that changes the `lg` breakpoint keeps the JS and the layout in step.
  get isDrawer() {
    return this.hasPanelTarget && getComputedStyle(this.panelTarget).position === "fixed"
  }

  render(open) {
    if (!this.hasPanelTarget) return
    const drawer = this.isDrawer
    this.panelTarget.classList.toggle("-translate-x-full", !open)
    this.panelTarget.inert = drawer && !open
    this.backdropTargets.forEach((backdrop) => backdrop.classList.toggle("hidden", !open))
    this.contentTargets.forEach((element) => { element.inert = drawer && open })
    this.toggleTargets.forEach((toggle) => toggle.setAttribute("aria-expanded", String(open)))
  }
}
