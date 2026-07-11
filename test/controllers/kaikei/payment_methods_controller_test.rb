require "test_helper"

class Kaikei::PaymentMethodsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  # test "index shows current user's payment methods" do
  #   get kaikei_payment_methods_path
  #   assert_response :success
  #   assert_match kaikei_payment_methods(:alice_cash).name, response.body
  # end

  test "destroy soft-deletes the payment method without touching referencing transactions" do
    payment_method = kaikei_payment_methods(:alice_cash)
    transaction = kaikei_transactions(:alice_lunch)

    delete kaikei_payment_method_path(payment_method)

    assert_redirected_to kaikei_settings_path(tab: "payment_method")
    assert payment_method.reload.discarded?
    assert_equal payment_method.id, transaction.reload.payment_method_id
  end
end
