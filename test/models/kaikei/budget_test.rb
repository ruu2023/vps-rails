require "test_helper"

class Kaikei::BudgetTest < ActiveSupport::TestCase
  test "amount must be >= 1" do
    budget = Kaikei::Budget.new(
      user: users(:alice), category: kaikei_categories(:alice_food),
      amount: 0, year: Date.current.year, month: Date.current.month
    )
    assert_not budget.valid?
    assert_includes budget.errors[:amount], "must be greater than or equal to 1"
  end

  test "category must be an expense category" do
    budget = Kaikei::Budget.new(
      user: users(:alice), category: kaikei_categories(:alice_salary),
      amount: 1000, year: Date.current.year, month: Date.current.month
    )
    assert_not budget.valid?
    assert_includes budget.errors[:category], "は支出科目である必要があります"
  end

  test "duplicate user/category/year/month is invalid" do
    existing = kaikei_budgets(:alice_food_budget)
    budget = Kaikei::Budget.new(
      user: existing.user, category: existing.category,
      amount: 500, year: existing.year, month: existing.month
    )
    assert_not budget.valid?
  end

  test "progress_percentage is rounded to one decimal place and capped at 100" do
    budget = kaikei_budgets(:alice_food_budget)
    budget.update!(amount: 3)
    kaikei_transactions(:alice_lunch).update!(amount: 1)
    assert_equal 33.3, budget.reload.progress_percentage

    budget.update!(amount: 1)
    assert_equal 100.0, budget.reload.progress_percentage
  end
end
