import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rowsContainer", "row", "destroyField", "positionField", "dragHandle"]
  static values = {
    associationName: String,
    allowDestroy: Boolean,
    sortable: Boolean
  }

  connect() {
    this.rowIndex = this.rowTargets.length
    if (this.sortableValue) this.initSortable()
  }

  addRow(event) {
    event.preventDefault()
    const template = document.getElementById(`${this.associationNameValue}-nested-template`)
    if (!template) return

    const timestamp = new Date().getTime()
    const clone = template.content.cloneNode(true)

    clone.querySelectorAll("[name], [id], [for]").forEach((el) => {
      if (el.name) el.name = el.name.replace(/NEW_RECORD_INDEX/g, timestamp)
      if (el.id) el.id = el.id.replace(/NEW_RECORD_INDEX/g, timestamp)
      if (el.htmlFor) el.htmlFor = el.htmlFor.replace(/NEW_RECORD_INDEX/g, timestamp)
    })

    this.rowsContainerTarget.appendChild(clone)
    if (this.sortableValue) this.updatePositions()
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest("[data-cp-nested-form-target='row']")
    if (!row) return

    const idField = row.querySelector("input[name$='[id]']")
    if (idField && idField.value) {
      const destroyField = row.querySelector("[data-cp-nested-form-target='destroyField']")
      if (destroyField) destroyField.value = "1"
      row.style.display = "none"
    } else {
      row.remove()
    }
    if (this.sortableValue) this.updatePositions()
  }

  updatePositions() {
    this.rowTargets
      .filter((row) => row.style.display !== "none")
      .forEach((row, index) => {
        const posField = row.querySelector("[data-cp-nested-form-target='positionField']")
        if (posField) posField.value = index + 1
      })
  }

  initSortable() {
    this.rowTargets.forEach((row) => this.makeDraggable(row))

    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        mutation.addedNodes.forEach((node) => {
          if (node.nodeType === 1 && node.dataset.cpNestedFormTarget === "row") {
            this.makeDraggable(node)
          }
        })
      })
    })
    observer.observe(this.rowsContainerTarget, { childList: true })
  }

  makeDraggable(row) {
    const handle = row.querySelector("[data-cp-nested-form-target='dragHandle']")
    if (!handle) return

    row.setAttribute("draggable", "true")

    row.addEventListener("dragstart", (e) => {
      e.dataTransfer.effectAllowed = "move"
      row.classList.add("opacity-50")
      this.draggedRow = row
    })

    row.addEventListener("dragend", () => {
      row.classList.remove("opacity-50")
      this.draggedRow = null
      this.updatePositions()
    })

    row.addEventListener("dragover", (e) => {
      e.preventDefault()
      e.dataTransfer.dropEffect = "move"
    })

    row.addEventListener("drop", (e) => {
      e.preventDefault()
      if (this.draggedRow && this.draggedRow !== row) {
        const container = this.rowsContainerTarget
        const children = Array.from(container.children)
        const draggedIndex = children.indexOf(this.draggedRow)
        const targetIndex = children.indexOf(row)

        if (draggedIndex < targetIndex) {
          container.insertBefore(this.draggedRow, row.nextSibling)
        } else {
          container.insertBefore(this.draggedRow, row)
        }
      }
    })
  }
}
