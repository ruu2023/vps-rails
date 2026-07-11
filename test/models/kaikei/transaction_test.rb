require "test_helper"

class Kaikei::TransactionTest < ActiveSupport::TestCase
  test "amount must be >= 0" do
    transaction = Kaikei::Transaction.new(
      user: users(:alice),
      category: kaikei_categories(:alice_food),
      date: Date.current,
      amount: -1,
      type: "expense"
    )
    assert_not transaction.valid?
    assert_includes transaction.errors[:amount], "must be greater than or equal to 0"
  end

  test "type must match category default_type" do
    transaction = Kaikei::Transaction.new(
      user: users(:alice),
      category: kaikei_categories(:alice_food),
      date: Date.current,
      amount: 100,
      type: "income"
    )
    assert_not transaction.valid?
    assert_includes transaction.errors[:type], "は科目の収支区分(expense)と一致している必要があります"
  end

  test "valid when type matches category default_type" do
    transaction = Kaikei::Transaction.new(
      user: users(:alice),
      category: kaikei_categories(:alice_food),
      date: Date.current,
      amount: 100,
      type: "expense"
    )
    assert transaction.valid?
  end
end
