class Kaikei::PaymentMethodsController < Kaikei::BaseController
  before_action :set_payment_method, only: [ :edit, :update, :destroy ]

  def index
    @payment_methods = current_user.kaikei_payment_methods.order(:name)
  end

  def new
    @payment_method = current_user.kaikei_payment_methods.build
  end

  def create
    @payment_method = current_user.kaikei_payment_methods.build(payment_method_params)

    if @payment_method.save
      redirect_to kaikei_settings_path(tab: "payment_method"), notice: "支払方法を作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @payment_method.update(payment_method_params)
      redirect_to kaikei_settings_path(tab: "payment_method"), notice: "支払方法を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @payment_method.destroy
    redirect_to kaikei_payment_methods_path, notice: "支払方法を削除しました"
  end

  private

  def set_payment_method
    @payment_method = current_user.kaikei_payment_methods.find(params[:id])
  end

  def payment_method_params
    params.require(:kaikei_payment_method).permit(:name, :type)
  end
end
