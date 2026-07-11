class Kaikei::Transaction < ApplicationRecord
  self.table_name = "kaikei_transactions"
  self.inheritance_column = nil

  TYPES = %w[income expense].freeze

  belongs_to :user
  belongs_to :category, class_name: "Kaikei::Category"
  belongs_to :payment_method, class_name: "Kaikei::PaymentMethod", optional: true

  validates :date, presence: true
  validates :amount, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :type, inclusion: { in: TYPES }

  validate :type_matches_category_default_type

  scope :income, -> { where(type: "income") }
  scope :expense, -> { where(type: "expense") }
  scope :for_month, ->(year, month) {
    range = Date.new(year, month, 1)..Date.new(year, month, -1)
    where(date: range)
  }

  private

  def type_matches_category_default_type
    return if category.nil? || type.blank?

    if type != category.default_type
      errors.add(:type, "は科目の収支区分(#{category.default_type})と一致している必要があります")
    end
  end
end
