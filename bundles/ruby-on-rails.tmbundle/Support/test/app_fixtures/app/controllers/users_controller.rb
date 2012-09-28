class UsersController < ApplicationController
  def new
    @user = User.new
  end

  def create
    @user = User.new(params[:user])
  end
  
  def no_existing_views
    respond_to do |wants|
      wants.html {  } # format with an inline block
      wants.js do
        # format with a multi-line block
      end
      wants.xml # format without a block
      wants.wacky # non-standard format
    end
  end

  def existing_views
    respond_to do |wants|
      wants.html {  } # format with an inline block
      wants.js do
        # format with a multi-line block
      end
      wants.xml # format without a block
      wants.wacky # non-standard format
    end
  end
end