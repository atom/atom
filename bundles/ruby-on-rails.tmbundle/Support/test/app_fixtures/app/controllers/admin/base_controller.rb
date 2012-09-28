class Admin::BaseController < ApplicationController
  def edit
    @user = User.new(params[:user])
  end

  def update
    @user = User.new(params[:user])
  end
end