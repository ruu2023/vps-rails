class Kaikei::CategoriesController < Kaikei::BaseController
  before_action :set_category, only: [ :edit, :update, :destroy ]

  def index
    @categories = current_user.kaikei_categories.order(:sort_order)
  end

  def new
    @category = current_user.kaikei_categories.build
  end

  def create
    @category = current_user.kaikei_categories.build(category_params)
    @category.sort_order = current_user.kaikei_categories.maximum(:sort_order).to_i + 1

    if @category.save
      redirect_to kaikei_categories_path, notice: "科目を作成しました"
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @category.update(category_params)
      redirect_to kaikei_categories_path, notice: "科目を更新しました"
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @category.discard

    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to kaikei_categories_path, notice: "科目を削除しました" }
    end
  end

  private

  def set_category
    @category = current_user.kaikei_categories.find(params[:id])
  end

  def category_params
    params.require(:kaikei_category).permit(:name, :icon, :default_type)
  end
end
