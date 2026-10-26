import { Controller } from "@hotwired/stimulus"

// Removes a dismissible modal (IronAdmin::Ui::ModalComponent) from the page
// when its close button, its backdrop or the Escape key is used.
export default class extends Controller {
  close() {
    this.element.remove()
  }
}
