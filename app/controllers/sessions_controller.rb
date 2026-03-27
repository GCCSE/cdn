# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :require_authentication!, only: [ :create, :failure ]

  def create
    auth = request.env["omniauth.auth"]
    user = User.find_or_create_from_github(auth)
    session[:user_id] = user.id

    redirect_to root_path, notice: "Signed in with GitHub successfully."
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Signed out successfully."
  end

  def failure
    redirect_to root_path, alert: "GitHub authentication failed."
  end
end
