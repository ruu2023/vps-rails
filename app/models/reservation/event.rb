class Reservation::Event < ApplicationRecord
  self.table_name = "reservation_events"

  belongs_to :user

  # 移行データは過去日時の予定が大半のため、reservation:import_legacy_events
  # タスクからのみ立てて過去日時禁止バリデーションを迂回する。通常のコントローラ
  # 経由の作成では使用しない。
  attr_accessor :skip_past_validation

  validates :title, presence: true, length: { maximum: 50 }
  validates :start_time, presence: true

  validate :start_time_cannot_be_in_the_past, on: :create, unless: :skip_past_validation
  validate :end_time_cannot_be_before_start_time

  scope :within_range, ->(range_start, range_end) {
    where("start_time <= ? AND (end_time IS NULL OR end_time >= ?)", range_end, range_start)
  }

  private

  def start_time_cannot_be_in_the_past
    return if start_time.blank?

    if start_time < Time.zone.now
      errors.add(:start_time, "未来の時間にしてください")
    end
  end

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
