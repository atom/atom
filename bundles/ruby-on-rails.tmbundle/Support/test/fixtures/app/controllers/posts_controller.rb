class PostsController < ApplicationController
  def new
    @post = Post.new
  end

  def create
    @post = Post.new(params[:post])
  end

  def index
    respond_to do |wants|
      wants.html  { }
      wants.xml   { }
      wants.js    { }
      wants.wacky { }
    end
    respond_to do |format|
      format.html { }
    end
  end

  def edit
  end
end