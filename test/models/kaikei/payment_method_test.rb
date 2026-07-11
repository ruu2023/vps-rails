require "test_helper"

class Kaikei::PaymentMethodTest < ActiveSupport::TestCase
  test "requires a valid type" do
    payment_method = Kaikei::PaymentMethod.new(user: users(:alice), name: "test", type: "invalid")
    assert_not payment_method.valid?
    assert_includes payment_method.errors[:type], "is not included in the list"
  end

  test "discard soft-deletes the payment method without touching referencing transactions" do
    payment_method = kaikei_payment_methods(:alice_cash)
    transaction = kaikei_transactions(:alice_lunch)
    assert_equal payment_method.id, transaction.payment_method_id

    payment_method.discard

    assert payment_method.discarded?
    assert_not Kaikei::PaymentMethod.exists?(payment_method.id)
    assert Kaikei::PaymentMethod.unscoped.exists?(payment_method.id)
    assert_equal payment_method.id, transaction.reload.payment_method_id
    assert_equal payment_method.name, transaction.payment_method.name
  end
end
