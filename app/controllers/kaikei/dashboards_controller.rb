class Kaikei::DashboardsController < Kaikei::BaseController
  def show
    today = Date.current
    @current_income, @current_expense = monthly_totals(today.year, today.month)
    @current_balance = @current_income - @current_expense

    previous_month = today.prev_month
    previous_income, previous_expense = monthly_totals(previous_month.year, previous_month.month)
    previous_balance = previous_income - previous_expense
    @balance_change_rate = change_rate(@current_balance, previous_balance)

    @recent_transactions = current_user.kaikei_transactions
      .includes(:category, :payment_method)
      .order(date: :desc, id: :desc)
      .limit(5)

    @monthly_series = (0..5).map { |i| today.prev_month(i) }.reverse.map do |month|
      income, expense = monthly_totals(month.year, month.month)
      { label: month.strftime("%Y-%m"), income: income, expense: expense }
    end

    @budgets = current_user.kaikei_budgets.where(year: today.year, month: today.month).includes(:category)
  end

  private

  def monthly_totals(year, month)
    scope = current_user.kaikei_transactions.for_month(year, month)
    [ scope.income.sum(:amount), scope.expense.sum(:amount) ]
  end

  def change_rate(current_value, previous_value)
    return 0.0 if previous_value.zero?

    ((current_value - previous_value).to_f / previous_value.abs * 100).round(1)
  end
end
