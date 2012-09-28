class Exception
  alias :original_clean_backtrace :clean_backtrace

  def add_links_to_backtrace(lines)
    lines.collect do |line|
      expanded = line.gsub '#{RAILS_ROOT}', RAILS_ROOT
      if match = expanded.match(/^(.+):(\d+):in/) or match = expanded.match(/^(.+):(\d+)\s*$/)
        file = File.expand_path(match[1])
        line_number = match[2]
        html = "<a href='txmt://open?url=file://#{file}&line=#{line_number}'>#{line}</a>"
      else
        line
      end
    end
  end

  def clean_backtrace
    add_links_to_backtrace(original_clean_backtrace)
  end
end

module ActionView
  class TemplateError < ActionViewError
    def line_number_link
      file = File.expand_path(@file_path)
      "<a href='txmt://open?url=file://#{file}&line=#{line_number}'>#{line_number}</a>"
    end
  end
end

class ActionController::Base
protected
  alias backtracer_original_template_path_for_local_rescue template_path_for_local_rescue
  def template_path_for_local_rescue(exception)
    if ActionView::TemplateError === exception
      File.dirname(__FILE__) + "/../templates/rescues/template_error.erb"
    else
      backtracer_original_template_path_for_local_rescue(exception)
    end
  end

end
