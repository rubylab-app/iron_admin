import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["opSelect", "betweenRow"]

  toggle() {
    const isBetween = this.opSelectTarget.value === "between"
    this.betweenRowTarget.classList.toggle("hidden", !isBetween)
  }
}
