class SessionsController < ApplicationController
  skip_before_action :authenticate_user!, only: [ :new, :create, :failure ]

  def new
    redirect_to root_path if logged_in?
  end

  def create
    auth = request.env["omniauth.auth"]
    user = User.from_google_omniauth(auth)
    session[:user_id] = user.id
    redirect_to root_path, notice: "ログインしました"
  end

  def failure
    redirect_to login_path, alert: "ログインに失敗しました"
  end

  def destroy
    reset_session
    redirect_to login_path, notice: "ログアウトしました"
  end
end
