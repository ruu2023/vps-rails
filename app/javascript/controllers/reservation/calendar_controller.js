import { Controller } from "@hotwired/stimulus"
import { Calendar } from "@fullcalendar/core"
import dayGridPlugin from "@fullcalendar/daygrid"
import timeGridPlugin from "@fullcalendar/timegrid"
import interactionPlugin from "@fullcalendar/interaction"

const WEEKDAY_LABELS = [ "日", "月", "火", "水", "木", "金", "土" ]

export default class extends Controller {
  static targets = [ "calendar", "events", "holidays", "modalLink" ]
  static values = { startDate: String }

  connect() {
    // { "2026-05-03": "憲法記念日", ... }
    this.holidays = JSON.parse(this.holidaysTarget.textContent)

    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [ dayGridPlugin, timeGridPlugin, interactionPlugin ],
      initialView: "dayGridMonth",
      initialDate: this.startDateValue || undefined,
      firstDay: 0,
      height: "100%",
      events: this.pendingEvents ?? JSON.parse(this.eventsTarget.textContent),
      eventDisplay: "block",
      displayEventTime: false,
      dayMaxEvents: true,
      buttonText: { today: "今日" },
      dayHeaderContent: (arg) => WEEKDAY_LABELS[arg.dow],
      dayHeaderClassNames: (arg) => this.weekdayClassNames(arg.dow),
      dayCellClassNames: (arg) => this.dayCellClassNames(arg),
      dayCellDidMount: (arg) => this.dayCellDidMount(arg),
      datesSet: (arg) => this.updateTitle(arg),
      dateClick: (info) => this.openModal(`/reservation/events/new?date=${info.dateStr}`),
      eventClick: (info) => {
        info.jsEvent.preventDefault()
        this.closePopoverIfNeeded(info.el)
        this.openModal(`/reservation/events/${info.event.id}/edit`)
      }
    })

    this.calendar.render()
  }

  disconnect() {
    this.calendar?.destroy()
    this.calendar = null
  }

  // Turbo Stream で events ターゲットが replace されるたびに呼ばれる。
  // FullCalendar は静的な events 配列を初期化時に渡すだけなので、
  // Turbo Stream の DOM 置換だけでは内部状態が更新されない。ここで
  // イベントソースを丸ごと差し替えて反映させる(初回接続時は
  // calendar がまだ存在しないため、connect() 側で読み込ませる)。
  eventsTargetConnected(element) {
    const events = JSON.parse(element.textContent)

    if (this.calendar) {
      this.calendar.removeAllEventSources()
      this.calendar.addEventSource(events)
    } else {
      this.pendingEvents = events
    }
  }

  openModal(url) {
    this.modalLinkTarget.href = url
    this.modalLinkTarget.click()
  }

  // +N more のポップオーバー内からイベントを開く場合、遷移前に
  // ポップオーバーを閉じておかないと開いたままモーダルの裏に残ってしまう。
  closePopoverIfNeeded(el) {
    if (!el.closest(".fc-popover")) return
    document.querySelector(".fc-popover-close")?.click()
  }

  updateTitle(arg) {
    const titleEl = this.calendarTarget.querySelector(".fc-toolbar-title")
    if (!titleEl) return

    const date = arg.view.currentStart
    titleEl.innerHTML =
      `<span class="reservation-calendar-title-month">${date.getMonth() + 1}月</span>` +
      `<span class="reservation-calendar-title-year">${date.getFullYear()}</span>`
  }

  weekdayClassNames(dow) {
    if (dow === 0) return [ "is-sunday" ]
    if (dow === 6) return [ "is-saturday" ]
    return []
  }

  dayCellClassNames(arg) {
    const classNames = []
    const dow = arg.date.getDay()

    if (this.holidays[this.formatLocalDate(arg.date)]) classNames.push("is-holiday")
    else if (dow === 6) classNames.push("is-saturday")
    else if (dow === 0) classNames.push("is-sunday")

    if (arg.isToday) classNames.push("is-today")

    return classNames
  }

  dayCellDidMount(arg) {
    const holidayName = this.holidays[this.formatLocalDate(arg.date)]
    if (!holidayName) return

    const top = arg.el.querySelector(".fc-daygrid-day-top")
    if (!top) return

    const label = document.createElement("span")
    label.className = "reservation-holiday-name"
    label.textContent = holidayName
    top.appendChild(label)
  }

  formatLocalDate(date) {
    const pad = (n) => String(n).padStart(2, "0")
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
  }
}
