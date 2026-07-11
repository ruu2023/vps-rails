require "test_helper"

class Kaikei::DashboardsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "show renders successfully" do
    get kaikei_dashboard_path
    assert_response :success
  end
end
