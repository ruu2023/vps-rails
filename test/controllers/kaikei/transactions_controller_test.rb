require "test_helper"

class Kaikei::TransactionsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  # test "index shows current user's transactions" do
  #   get kaikei_transactions_path
  #   assert_response :success
  # end

  test "create with mismatched type/category is rejected" do
    assert_no_difference -> { users(:alice).kaikei_transactions.count } do
      post kaikei_transactions_path, params: {
        kaikei_transaction: {
          date: Date.current, amount: 100, type: "income",
          category_id: kaikei_categories(:alice_food).id
        }
      }
    end
    assert_response :unprocessable_entity
  end

  test "create with valid params succeeds" do
    assert_difference -> { users(:alice).kaikei_transactions.count }, 1 do
      post kaikei_transactions_path, params: {
        kaikei_transaction: {
          date: Date.current, amount: 500, type: "expense",
          category_id: kaikei_categories(:alice_food).id
        }
      }
    end
    assert_redirected_to kaikei_dashboard_path
  end

  test "cannot destroy another user's transaction" do
    transaction = kaikei_transactions(:alice_lunch)
    transaction.update_column(:user_id, users(:bob).id)

    delete kaikei_transaction_path(transaction)

    assert_response :not_found
  end
end
