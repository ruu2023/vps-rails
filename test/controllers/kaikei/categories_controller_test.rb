require "test_helper"

class Kaikei::CategoriesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:alice) }

  test "redirects to login when not authenticated" do
    delete logout_path
    get kaikei_categories_path
    assert_redirected_to login_path
  end

  # test "index only shows current user's categories" do
  #   get kaikei_categories_path
  #   assert_response :success
  #   assert_match kaikei_categories(:alice_food).name, response.body
  #   assert_no_match "/kaikei/categories/#{kaikei_categories(:bob_food).id}/edit", response.body
  # end

  test "create adds a category for the current user" do
    assert_difference -> { users(:alice).kaikei_categories.count }, 1 do
      post kaikei_categories_path, params: { kaikei_category: { name: "交通費", default_type: "expense" } }
    end
    assert_redirected_to kaikei_settings_path(tab: "category")
  end

  test "cannot edit another user's category" do
    get edit_kaikei_category_path(kaikei_categories(:bob_food))
    assert_response :not_found
  end

  test "destroy soft-deletes the category" do
    category = kaikei_categories(:alice_food)
    delete kaikei_category_path(category)
    assert_redirected_to kaikei_settings_path(tab: "category")
    assert category.reload.discarded?
  end

  test "destroy via turbo_stream removes the row without a redirect" do
    category = kaikei_categories(:alice_food)
    delete kaikei_category_path(category), as: :turbo_stream

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_match %(turbo-stream action="remove" target="#{ActionView::RecordIdentifier.dom_id(category)}"), response.body
    assert category.reload.discarded?
  end
end
