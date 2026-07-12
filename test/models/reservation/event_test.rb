require "test_helper"

class Reservation::EventTest < ActiveSupport::TestCase
  test "title is required" do
    event = Reservation::Event.new(user: users(:alice), start_time: 1.day.from_now)
    assert_not event.valid?
    assert_includes event.errors[:title], "can't be blank"
  end

  test "title cannot exceed 50 characters" do
    event = Reservation::Event.new(user: users(:alice), title: "a" * 51, start_time: 1.day.from_now)
    assert_not event.valid?
    assert_includes event.errors[:title], "is too long (maximum is 50 characters)"
  end

  test "start_time is required" do
    event = Reservation::Event.new(user: users(:alice), title: "予定")
    assert_not event.valid?
    assert_includes event.errors[:start_time], "can't be blank"
  end

  test "start_time cannot be in the past on create" do
    event = Reservation::Event.new(user: users(:alice), title: "予定", start_time: 1.day.ago)
    assert_not event.valid?
    assert_includes event.errors[:start_time], "未来の時間にしてください"
  end

  test "past start_time is allowed on update" do
    event = Reservation::Event.create!(user: users(:alice), title: "予定", start_time: 1.day.from_now)
    event.start_time = 1.day.ago
    assert event.valid?
  end

  test "end_time equal to start_time is invalid" do
    time = 1.day.from_now
    event = Reservation::Event.new(user: users(:alice), title: "予定", start_time: time, end_time: time)
    assert_not event.valid?
    assert_includes event.errors[:end_time], "開始よりあとの時間に!"
  end

  test "end_time before start_time is invalid" do
    event = Reservation::Event.new(
      user: users(:alice), title: "予定", start_time: 1.day.from_now, end_time: 1.day.from_now - 1.hour
    )
    assert_not event.valid?
    assert_includes event.errors[:end_time], "開始よりあとの時間に!"
  end

  test "end_time without start_time is invalid" do
    event = Reservation::Event.new(user: users(:alice), title: "予定", end_time: 1.day.from_now)
    assert_not event.valid?
    assert_includes event.errors[:start_time], "先に選んでね"
  end

  test "valid with end_time after start_time" do
    event = Reservation::Event.new(
      user: users(:alice), title: "予定", start_time: 1.day.from_now, end_time: 1.day.from_now + 1.hour
    )
    assert event.valid?
  end

  test "valid without end_time when has_end_time is false" do
    event = Reservation::Event.new(user: users(:alice), title: "予定", start_time: 1.day.from_now)
    assert event.valid?
  end

  test "within_range includes events with NULL end_time (known_issues #1 regression)" do
    range_start = 1.day.from_now.beginning_of_day
    range_end = 2.days.from_now.end_of_day
    event = Reservation::Event.create!(
      user: users(:alice), title: "終了時刻なし", start_time: 1.day.from_now.change(hour: 9), has_end_time: false
    )

    assert_includes Reservation::Event.within_range(range_start, range_end), event
  end
end
