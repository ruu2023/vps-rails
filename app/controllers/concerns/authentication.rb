module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :authenticate_user!
    helper_method :current_user, :logged_in?
  end

  def current_user
    @current_user ||= User.find_by(id: session[:user_id])
  end

  def logged_in?
    current_user.present?
  end

  def authenticate_user!
    redirect_to login_path, alert: "ログインしてください" unless logged_in?
  end
end
