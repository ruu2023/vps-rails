class Kaikei::AnalyticsController < Kaikei::BaseController
  PER_PAGE = 20

  def show
    @start_date = parse_date(params[:start_date]) || Date.current.beginning_of_month
    @end_date = parse_date(params[:end_date]) || Date.current.end_of_month
    @type = params[:type].presence_in(Kaikei::Transaction::TYPES)
    @category_id = params[:category_id].presence

    @categories = current_user.kaikei_categories.order(:sort_order)

    period_scope = current_user.kaikei_transactions.where(date: @start_date..@end_date)
    @income_total = period_scope.income.sum(:amount)
    @expense_total = period_scope.expense.sum(:amount)
    @balance = @income_total - @expense_total

    @monthly_series = monthly_series(period_scope)
    @category_series = category_series(period_scope)

    filtered_scope = period_scope
    filtered_scope = filtered_scope.where(type: @type) if @type
    filtered_scope = filtered_scope.where(category_id: @category_id) if @category_id

    @page = [ params[:page].to_i, 1 ].max
    @total_count = filtered_scope.count
    @transactions = filtered_scope.includes(:category, :payment_method)
      .order(date: :desc, id: :desc)
      .limit(PER_PAGE)
      .offset((@page - 1) * PER_PAGE)
  end

  private

  def parse_date(value)
    Date.parse(value)
  rescue ArgumentError, TypeError
    nil
  end

  def monthly_series(scope)
    sums = scope.group("strftime('%Y-%m', date)", :type).sum(:amount)

    months = []
    month = @start_date.beginning_of_month
    while month <= @end_date.beginning_of_month
      months << month
      month = month.next_month
    end

    months.map do |m|
      key = m.strftime("%Y-%m")
      { label: key, income: sums[[ key, "income" ]] || 0, expense: sums[[ key, "expense" ]] || 0 }
    end
  end

  def category_series(scope)
    sums = scope.group(:category_id).sum(:amount)
    categories_by_id = @categories.index_by(&:id)

    sums.sort_by { |_, amount| -amount }.first(5).map do |category_id, amount|
      { name: categories_by_id[category_id]&.name || "(不明)", amount: amount }
    end
  end
end
