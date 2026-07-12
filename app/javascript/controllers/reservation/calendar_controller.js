import { Controller } from "@hotwired/stimulus"
import { Calendar } from "@fullcalendar/core"
import dayGridPlugin from "@fullcalendar/daygrid"
import timeGridPlugin from "@fullcalendar/timegrid"
import interactionPlugin from "@fullcalendar/interaction"

const WEEKDAY_LABELS = [ "日", "月", "火", "水", "木", "金", "土" ]

export default class extends Controller {
  static targets = [ "calendar", "events", "holidays", "modalLink" ]

  connect() {
    this.holidays = new Set(JSON.parse(this.holidaysTarget.textContent))

    this.calendar = new Calendar(this.calendarTarget, {
      plugins: [ dayGridPlugin, timeGridPlugin, interactionPlugin ],
      initialView: "dayGridMonth",
      firstDay: 0,
      height: "auto",
      events: this.pendingEvents ?? JSON.parse(this.eventsTarget.textContent),
      buttonText: { today: "今日" },
      dayHeaderContent: (arg) => WEEKDAY_LABELS[arg.dow],
      dayCellClassNames: (arg) => this.dayCellClassNames(arg),
      dateClick: (info) => this.openModal(`/reservation/events/new?date=${info.dateStr}`),
      eventClick: (info) => {
        info.jsEvent.preventDefault()
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

  dayCellClassNames(arg) {
    if (this.holidays.has(this.formatLocalDate(arg.date)) || arg.dow === 0) return [ "text-red-500" ]
    if (arg.dow === 6) return [ "text-blue-500" ]
    return []
  }

  formatLocalDate(date) {
    const pad = (n) => String(n).padStart(2, "0")
    return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}`
  }
}
