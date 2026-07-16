require "test_helper"

class Kaikei::ExportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "new renders the export form" do
    get new_kaikei_exports_path
    assert_response :success
  end

  test "create downloads a CSV with the transaction data" do
    post kaikei_exports_path, params: {
      start_date: 1.year.ago.to_date, end_date: Date.tomorrow,
      kind: "transactions", format: "csv"
    }
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match kaikei_transactions(:alice_lunch).client_name.to_s, response.body if kaikei_transactions(:alice_lunch).client_name
  end

  test "create downloads a journal-format Excel file" do
    post kaikei_exports_path, params: {
      start_date: 1.year.ago.to_date, end_date: Date.tomorrow,
      kind: "journal", format: "excel"
    }
    assert_response :success
    assert_equal "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet", response.media_type
  end

  test "create downloads a PDF file" do
    post kaikei_exports_path, params: {
      start_date: 1.year.ago.to_date, end_date: Date.tomorrow,
      kind: "transactions", format: "pdf"
    }
    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "create downloads a category-settings CSV, ignoring the date range" do
    post kaikei_exports_path, params: {
      start_date: "", end_date: "",
      kind: "categories", format: "csv"
    }
    assert_response :success
    assert_equal "text/csv", response.media_type
    assert_match kaikei_categories(:alice_food).name, response.body
  end
end
