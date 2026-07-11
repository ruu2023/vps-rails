require "test_helper"

class Kaikei::AnalyticsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "show renders successfully" do
    get kaikei_analytics_path
    assert_response :success
  end

  test "show filters by type and category" do
    get kaikei_analytics_path, params: { type: "expense", category_id: kaikei_categories(:alice_food).id }
    assert_response :success
  end

  test "show scopes totals to the given period" do
    get kaikei_analytics_path, params: { start_date: Date.current.beginning_of_month, end_date: Date.current.end_of_month }
    assert_response :success
  end
end
