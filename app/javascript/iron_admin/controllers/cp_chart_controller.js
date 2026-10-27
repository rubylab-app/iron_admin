import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["canvas"]
  static values = { config: Object }

  connect() {
    if (typeof Chart !== "undefined") {
      this.initChart()
    } else {
      this.boundInit = () => this.initChart()
      document.addEventListener("chartjs:loaded", this.boundInit)
    }
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
      this.chart = null
    }
    if (this.boundInit) {
      document.removeEventListener("chartjs:loaded", this.boundInit)
    }
  }

  initChart() {
    if (!this.hasCanvasTarget) return
    // A canvas does not inherit CSS fonts: draw the chart in the theme font of its card,
    // and redraw it once a web font such as Inter has loaded.
    Chart.defaults.font.family = getComputedStyle(this.element).fontFamily
    this.chart = new Chart(this.canvasTarget, this.configValue)
    document.fonts?.ready.then(() => this.chart?.update("none"))
  }
}
