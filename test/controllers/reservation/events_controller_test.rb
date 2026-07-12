require "test_helper"
require "turbo/broadcastable/test_helper"

class Reservation::EventsControllerTest < ActionDispatch::IntegrationTest
  include Turbo::Broadcastable::TestHelper

  setup { sign_in users(:alice) }

  test "index shows only the current user's events" do
    get reservation_events_path
    assert_response :success
    assert_select "body", text: /#{reservation_events(:alice_meeting).title}/
  end

  test "create with valid params succeeds" do
    assert_difference -> { users(:alice).reservation_events.count }, 1 do
      post reservation_events_path, params: {
        reservation_event: { title: "新しい予定", start_time: 1.day.from_now }
      }
    end
    assert_redirected_to reservation_events_path
  end

  test "create with invalid params is rejected" do
    assert_no_difference -> { users(:alice).reservation_events.count } do
      post reservation_events_path, params: {
        reservation_event: { title: "", start_time: 1.day.from_now }
      }
    end
    assert_response :unprocessable_entity
  end

  test "cannot edit another user's event" do
    event = reservation_events(:alice_meeting)
    event.update_column(:user_id, users(:bob).id)

    get edit_reservation_event_path(event)

    assert_response :not_found
  end

  test "cannot update another user's event" do
    event = reservation_events(:alice_meeting)
    event.update_column(:user_id, users(:bob).id)

    patch reservation_event_path(event), params: { reservation_event: { title: "乗っ取り" } }

    assert_response :not_found
  end

  test "cannot destroy another user's event" do
    event = reservation_events(:alice_meeting)
    event.update_column(:user_id, users(:bob).id)

    delete reservation_event_path(event)

    assert_response :not_found
  end

  test "destroy removes the event" do
    event = reservation_events(:alice_meeting)

    assert_difference -> { Reservation::Event.count }, -1 do
      delete reservation_event_path(event)
    end
    assert_redirected_to reservation_events_path
  end

  test "create broadcasts a calendar refresh to the current user's stream" do
    assert_turbo_stream_broadcasts "reservation_events_user_#{users(:alice).id}" do
      post reservation_events_path, params: {
        reservation_event: { title: "配信テスト", start_time: 1.day.from_now }
      }
    end
  end

  test "update broadcasts a calendar refresh" do
    event = reservation_events(:alice_meeting)

    assert_turbo_stream_broadcasts "reservation_events_user_#{users(:alice).id}" do
      patch reservation_event_path(event), params: { reservation_event: { title: "更新後タイトル" } }
    end
  end

  test "destroy broadcasts a calendar refresh" do
    event = reservation_events(:alice_meeting)

    assert_turbo_stream_broadcasts "reservation_events_user_#{users(:alice).id}" do
      delete reservation_event_path(event)
    end
  end

  test "invalid create does not broadcast" do
    assert_no_turbo_stream_broadcasts "reservation_events_user_#{users(:alice).id}" do
      post reservation_events_path, params: { reservation_event: { title: "", start_time: 1.day.from_now } }
    end
  end
end
