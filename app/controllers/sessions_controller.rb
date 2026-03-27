# frozen_string_literal: true

class SessionsController < ApplicationController
  skip_before_action :require_authentication!, only: [ :create ]

  def create
    session[:user_id] ||= User.create_guest!.id
    redirect_to root_path, notice: "Session started successfully!"
  end

  def destroy
    reset_session
    redirect_to root_path, notice: "Session ended successfully."
  end
end
