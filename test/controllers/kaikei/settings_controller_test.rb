require "test_helper"

class Kaikei::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "show renders successfully with default tab" do
    get kaikei_settings_path
    assert_response :success
  end

  test "show renders successfully for each known tab" do
    Kaikei::SettingsController::TABS.each do |tab|
      get kaikei_settings_path(tab: tab)
      assert_response :success
    end
  end

  test "show falls back to export tab for an unknown tab param" do
    get kaikei_settings_path(tab: "budgets")
    assert_response :success
  end
end
