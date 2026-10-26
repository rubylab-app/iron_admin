import { Controller } from "@hotwired/stimulus"

// Keeps a color picker and its hex text input showing the same color.
// Only the text input has a name, so the form submits exactly one value.
const HEX_COLOR = /^#(?:[0-9a-f]{3}){1,2}$/i

export default class extends Controller {
  static targets = ["picker", "text"]

  connect() {
    this.fromText()
  }

  fromPicker() {
    this.textTarget.value = this.pickerTarget.value
  }

  // The picker only holds #rrggbb, so text that is not a hex color is left for the
  // input's pattern to reject on submit instead of being dropped here.
  fromText() {
    const value = this.textTarget.value
    if (HEX_COLOR.test(value)) this.pickerTarget.value = toSixDigits(value)
  }
}

function toSixDigits(hex) {
  const digits = hex.slice(1).toLowerCase()
  if (digits.length === 6) return `#${digits}`

  return `#${[...digits].map((digit) => digit + digit).join("")}`
}
