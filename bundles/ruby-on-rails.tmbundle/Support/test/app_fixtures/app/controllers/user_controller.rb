class UserController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
  end
end