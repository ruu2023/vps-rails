class Kaikei::SettingsController < Kaikei::BaseController
  TABS = %w[export category payment_method profile notifications appearance about].freeze

  def show
    @tab = params[:tab].presence_in(TABS) || "export"

    @categories = current_user.kaikei_categories.order(:sort_order)
    @income_categories = @categories.select { |c| c.default_type == "income" }
    @expense_categories = @categories.select { |c| c.default_type == "expense" }

    @payment_methods = current_user.kaikei_payment_methods.order(:name)
    @income_payment_methods = @payment_methods.select { |pm| pm.type == "income" }
    @expense_payment_methods = @payment_methods.select { |pm| pm.type == "expense" }

    @new_payment_method = current_user.kaikei_payment_methods.build(type: "expense")

    today = Date.current
    @export_start_date = today.beginning_of_month
    @export_end_date = today.end_of_month
  end
end
