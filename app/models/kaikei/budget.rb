class Kaikei::Budget < ApplicationRecord
  self.table_name = "kaikei_budgets"

  belongs_to :user
  belongs_to :category, class_name: "Kaikei::Category"

  validates :amount, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 1 }
  validates :month, inclusion: { in: 1..12 }
  validates :category_id, uniqueness: { scope: [ :user_id, :year, :month ] }

  validate :category_must_be_expense_type

  def actual_spent
    user.kaikei_transactions
      .expense
      .where(category_id: category_id)
      .for_month(year, month)
      .sum(:amount)
  end

  def progress_percentage
    return 0.0 if amount.to_i <= 0

    [ (actual_spent.to_f / amount * 100), 100 ].min.round(1)
  end

  def remaining_amount
    [ amount - actual_spent, 0 ].max
  end

  def over_budget?
    actual_spent > amount
  end

  def warning_level
    if progress_percentage >= 100
      "danger"
    elsif progress_percentage >= 80
      "warning"
    else
      "normal"
    end
  end

  private

  def category_must_be_expense_type
    return if category.nil?

    if category.default_type != "expense"
      errors.add(:category, "は支出科目である必要があります")
    end
  end
end
