import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "start", "end", "toggle", "endWrapper" ]
  static values = { confirmPast: Boolean }

  connect() {
    this.updateConfirmPast()
  }

  sync() {
    this.updateConfirmPast()

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

  // 新規作成のみ対象(編集時は元々過去日時を許容しているため確認不要)。
  // data-turbo-confirm は送信直前に Turbo が読みに来るので、値の変更に
  // 追随して都度セット/削除しておけば window.confirm より確実にタイミングが合う。
  updateConfirmPast() {
    if (!this.confirmPastValue || !this.hasStartTarget) return

    const start = new Date(this.startTarget.value)
    const isPast = !Number.isNaN(start.getTime()) && start < new Date()

    if (isPast) {
      this.element.setAttribute("data-turbo-confirm", "開始日時が現在より過去ですが、登録してよろしいですか？")
    } else {
      this.element.removeAttribute("data-turbo-confirm")
    }
  }

  toLocalInputValue(date) {
    const pad = (n) => String(n).padStart(2, "0")
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
  }
}
