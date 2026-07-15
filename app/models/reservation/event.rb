class Reservation::Event < ApplicationRecord
  self.table_name = "reservation_events"

  belongs_to :user

  validates :title, presence: true, length: { maximum: 50 }
  validates :start_time, presence: true

  validate :end_time_cannot_be_before_start_time

  scope :within_range, ->(range_start, range_end) {
    where("start_time <= ? AND (end_time IS NULL OR end_time >= ?)", range_end, range_start)
  }

  private

  def end_time_cannot_be_before_start_time
    return if end_time.blank?

    if start_time.blank?
      errors.add(:start_time, "先に選んでね")
      return
    end

    if end_time <= start_time
      errors.add(:end_time, "開始よりあとの時間に!")
    end
  end
end
