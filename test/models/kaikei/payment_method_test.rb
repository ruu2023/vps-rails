require "test_helper"

class Kaikei::PaymentMethodTest < ActiveSupport::TestCase
  test "requires a valid type" do
    payment_method = Kaikei::PaymentMethod.new(user: users(:alice), name: "test", type: "invalid")
    assert_not payment_method.valid?
    assert_includes payment_method.errors[:type], "is not included in the list"
  end

  test "deleting a payment method nullifies referencing transactions" do
    payment_method = kaikei_payment_methods(:alice_cash)
    transaction = kaikei_transactions(:alice_lunch)
    assert_equal payment_method.id, transaction.payment_method_id

    payment_method.destroy

    assert_nil transaction.reload.payment_method_id
  end
end
