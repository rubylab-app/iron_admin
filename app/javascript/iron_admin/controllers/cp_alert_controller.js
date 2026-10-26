import { Controller } from "@hotwired/stimulus"

// Removes a dismissible alert (IronAdmin::Ui::AlertComponent), such as a
// flash message, from the page.
export default class extends Controller {
  dismiss() {
    this.element.remove()
  }
}
