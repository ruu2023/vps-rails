class Kaikei::TransactionsController < Kaikei::BaseController
  PER_PAGE = 20

  before_action :set_transaction, only: [ :edit, :update, :destroy ]

  # def index
  #   scope = current_user.kaikei_transactions.includes(:category, :payment_method).order(date: :desc, id: :desc)
  #   scope = scope.where(type: params[:type]) if params[:type].present?
  #   scope = scope.where(category_id: params[:category_id]) if params[:category_id].present?
  #   scope = scope.where(date: params[:start_date]..) if params[:start_date].present?
  #   scope = scope.where(date: ..params[:end_date]) if params[:end_date].present?
  #
  #   @page = (params[:page] || 1).to_i
  #   @transactions = scope.limit(PER_PAGE).offset((@page - 1) * PER_PAGE)
  #   @total_count = scope.count
  #   @categories = current_user.kaikei_categories.order(:sort_order)
  # end

  def new
    type = params[:type].presence_in(Kaikei::Transaction::TYPES)
    @transaction = current_user.kaikei_transactions.build(date: Date.current, type: type)
    load_form_collections
  end

  def create
    @transaction = current_user.kaikei_transactions.build(transaction_params)

    if @transaction.save
      redirect_to kaikei_dashboard_path, notice: "取引を登録しました"
    else
      load_form_collections
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_collections
  end

  def update
    if @transaction.update(transaction_params)
      redirect_to kaikei_dashboard_path, notice: "取引を更新しました"
    else
      load_form_collections
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @transaction.destroy
    redirect_to kaikei_dashboard_path, notice: "取引を削除しました"
  end

  private

  def set_transaction
    @transaction = current_user.kaikei_transactions.find(params[:id])
  end

  def load_form_collections
    @categories = current_user.kaikei_categories.order(:sort_order)
    @payment_methods = current_user.kaikei_payment_methods.order(:name)
  end

  def transaction_params
    params.require(:kaikei_transaction).permit(:date, :amount, :type, :category_id, :payment_method_id, :client_name, :memo)
  end
end
