require "test_helper"

class Kaikei::CategoryTest < ActiveSupport::TestCase
  test "requires a valid default_type" do
    category = Kaikei::Category.new(user: users(:alice), name: "test", default_type: "invalid")
    assert_not category.valid?
    assert_includes category.errors[:default_type], "is not included in the list"
  end

  test "categories are scoped per user" do
    assert_includes users(:alice).kaikei_categories, kaikei_categories(:alice_food)
    assert_not_includes users(:alice).kaikei_categories, kaikei_categories(:bob_food)
  end

  test "discard soft-deletes the category" do
    category = kaikei_categories(:alice_food)
    category.discard
    assert category.discarded?
    assert_not Kaikei::Category.exists?(category.id)
    assert Kaikei::Category.unscoped.exists?(category.id)
  end
end
