require 'ostruct'

RAILS_ROOT.replace File.dirname(__FILE__)
::MAC_OS_X = (`uname`.chomp == "Darwin") rescue false

class MockController
  attr_accessor :template, :session, :params, :cookies

  def initialize(body = "")
    @body = body
    @performed_render = true
    @params = {:controller => 'test', :action => 'example'}
    @session = {}
    @cookies = {}
    template
  end

  def template
    @template ||= MockTemplate.new(self)
  end

  def response
    @response ||= OpenStruct.new(:body => @body, :headers => {})
  end

  def first_render
    @body
  end

  def request
    @request ||= MockRequest.new(false)
  end

  def action_name
    @params[:action]
  end
end

class MockTemplate
  def initialize(controller)
    @controller = controller
  end

  def first_render
    "example.rhtml"
  end
end

class MockRequest < OpenStruct.new(:xhr)
  alias_method :xhr?, :xhr
end

class FootnoteFilter
  def controller_filename
    __FILE__
  end

  def template_file_name
    __FILE__
  end

  def layout_file_name
    __FILE__
  end
end