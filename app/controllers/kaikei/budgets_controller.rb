class Kaikei::BudgetsController < Kaikei::BaseController
  before_action :set_budget, only: [ :update, :destroy ]

  def index
    @year = (params[:year] || Date.current.year).to_i
    @month = (params[:month] || Date.current.month).to_i
    @budgets = current_user.kaikei_budgets.where(year: @year, month: @month).includes(:category)
    @expense_categories = current_user.kaikei_categories.where(default_type: "expense").order(:sort_order)
  end

  def create
    @budget = current_user.kaikei_budgets.find_or_initialize_by(
      category_id: budget_params[:category_id],
      year: budget_params[:year],
      month: budget_params[:month]
    )
    @budget.amount = budget_params[:amount]

    if @budget.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to kaikei_budgets_path(year: @budget.year, month: @budget.month), notice: "予算を設定しました" }
      end
    else
      redirect_to kaikei_budgets_path, alert: @budget.errors.full_messages.to_sentence
    end
  end

  def update
    if @budget.update(amount: params[:kaikei_budget][:amount])
      respond_to do |format|
        format.turbo_stream { render "create" }
        format.html { redirect_to kaikei_budgets_path(year: @budget.year, month: @budget.month), notice: "予算を更新しました" }
      end
    else
      redirect_to kaikei_budgets_path, alert: @budget.errors.full_messages.to_sentence
    end
  end

  def destroy
    year = @budget.year
    month = @budget.month
    @budget.destroy

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to kaikei_budgets_path(year: year, month: month), notice: "予算を削除しました" }
    end
  end

  private

  def set_budget
    @budget = current_user.kaikei_budgets.find(params[:id])
  end

  def budget_params
    params.require(:kaikei_budget).permit(:category_id, :amount, :year, :month)
  end
end
