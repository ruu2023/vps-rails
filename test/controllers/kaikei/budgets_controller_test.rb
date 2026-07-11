require "test_helper"

class Kaikei::BudgetsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "index shows budgets for the given year/month" do
    budget = kaikei_budgets(:alice_food_budget)
    get kaikei_budgets_path(year: budget.year, month: budget.month)
    assert_response :success
    assert_match budget.category.name, response.body
  end

  test "create rejects budgets on income categories" do
    assert_no_difference -> { users(:alice).kaikei_budgets.count } do
      post kaikei_budgets_path, params: {
        kaikei_budget: {
          category_id: kaikei_categories(:alice_salary).id,
          amount: 1000, year: Date.current.year, month: Date.current.month
        }
      }
    end
    assert_redirected_to kaikei_budgets_path
  end

  test "create with same category/year/month updates existing budget" do
    budget = kaikei_budgets(:alice_food_budget)
    assert_no_difference -> { users(:alice).kaikei_budgets.count } do
      post kaikei_budgets_path, params: {
        kaikei_budget: {
          category_id: budget.category_id, amount: 99_999,
          year: budget.year, month: budget.month
        }
      }
    end
    assert_equal 99_999, budget.reload.amount
  end

  test "create via turbo_stream appends a new budget row" do
    category = kaikei_categories(:alice_food)
    users(:alice).kaikei_budgets.where(category: category).destroy_all

    post kaikei_budgets_path, params: {
      kaikei_budget: { category_id: category.id, amount: 5_000, year: Date.current.year, month: Date.current.month }
    }, as: :turbo_stream

    assert_response :success
    assert_match 'turbo-stream action="append" target="budgets"', response.body
  end

  test "destroy via turbo_stream removes the budget row" do
    budget = kaikei_budgets(:alice_food_budget)
    delete kaikei_budget_path(budget), as: :turbo_stream

    assert_response :success
    assert_match %(turbo-stream action="remove" target="#{ActionView::RecordIdentifier.dom_id(budget)}"), response.body
  end
end
