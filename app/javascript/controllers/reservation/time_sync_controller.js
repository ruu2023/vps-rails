import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "start", "end", "toggle", "endWrapper" ]

  sync() {
    if (!this.hasStartTarget || !this.hasEndTarget || !this.startTarget.value) return

    const start = new Date(this.startTarget.value)
    if (Number.isNaN(start.getTime())) return

    start.setHours(start.getHours() + 1)
    this.endTarget.value = this.toLocalInputValue(start)
  }

  toggleEnd() {
    if (!this.hasToggleTarget || !this.hasEndWrapperTarget) return

    this.endWrapperTarget.classList.toggle("hidden", !this.toggleTarget.checked)
  }

  toLocalInputValue(date) {
    const pad = (n) => String(n).padStart(2, "0")
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
  }
}
