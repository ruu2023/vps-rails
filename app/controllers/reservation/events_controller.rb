class Reservation::EventsController < Reservation::BaseController
  CALENDAR_EVENTS_DOM_ID = "reservation-calendar-events"

  before_action :set_event, only: [ :edit, :update, :destroy ]

  def index
    @events = current_user.reservation_events.order(:start_time)
    @calendar_events_json = calendar_events_json(@events)
    @holidays = HolidayJp.between(
      Date.current.beginning_of_year - 1.year, Date.current.end_of_year + 1.year
    ).to_h { |holiday| [ holiday.date.iso8601, holiday.name ] }
    @start_date = parse_start_date(params[:start_date])
  end

  def new
    @event = current_user.reservation_events.build(new_event_defaults)
  end

  def create
    @event = current_user.reservation_events.build(event_params)

    if @event.save
      broadcast_calendar_refresh
      redirect_to reservation_events_path, notice: "予定を作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @event.update(event_params)
      broadcast_calendar_refresh
      redirect_to reservation_events_path, notice: "予定を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @event.destroy
    broadcast_calendar_refresh
    redirect_to reservation_events_path, notice: "予定を削除しました"
  end

  private

  def set_event
    @event = current_user.reservation_events.find(params[:id])
  end

  def event_params
    params.require(:reservation_event).permit(:title, :start_time, :end_time, :has_end_time, :content)
  end

  def new_event_defaults
    return {} unless params[:date].present?

    date = Date.parse(params[:date])
    { start_time: date.in_time_zone.change(hour: 10), end_time: date.in_time_zone.change(hour: 11) }
  rescue ArgumentError
    {}
  end

  def parse_start_date(value)
    return nil unless value.present?

    Date.parse(value).iso8601
  rescue ArgumentError
    nil
  end

  def calendar_event_json(event)
    {
      id: event.id,
      title: event.title,
      start: event.start_time.iso8601,
      end: (event.end_time.iso8601 if event.has_end_time? && event.end_time.present?),
      allDay: false
    }
  end

  # "/" をエスケープし、埋め込み先の <script> タグが "</script>" で分断されるのを防ぐ
  def calendar_events_json(events)
    events.map { |event| calendar_event_json(event) }.to_json.gsub("/", '\/')
  end

  def broadcast_calendar_refresh
    json = calendar_events_json(current_user.reservation_events.order(:start_time))
    content = <<~HTML
      <script type="application/json" id="#{CALENDAR_EVENTS_DOM_ID}" data-reservation--calendar-target="events">#{json}</script>
    HTML

    Turbo::StreamsChannel.broadcast_replace_to(
      "reservation_events_user_#{current_user.id}",
      target: CALENDAR_EVENTS_DOM_ID,
      content: content
    )
  end
end
