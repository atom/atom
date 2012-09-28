class CommandGoToFile
  def self.alternate(args)
    current_file = RailsPath.new

    choice = args.empty? ? current_file.best_match : args.shift

    if choice.nil?
      puts "This file is not associated with any other files"
    elsif rails_path = current_file.rails_path_for(choice.to_sym)    
      if !rails_path.exists?
        rails_path, openatline, openatcol = create_file(rails_path, choice.to_sym)
        if rails_path.nil?
          TextMate.exit_discard
        end
        TextMate.rescan_project
      end

      TextMate.open rails_path, openatline, openatcol
    else
      puts "#{current_file.basename} does not have a #{choice}"
    end
  end  
  
  def self.on_current_line
    current_file = RailsPath.new

    # If the current line contains "render :partial", then open the partial.
    case TextMate.current_line

      # Example: render :partial => 'account/login'
      when /render[\s\(].*:partial\s*=>\s*['"](.+?)['"]/
        partial_name = $1
        modules = current_file.modules + [current_file.controller_name]

        # Check for absolute path to partial
        if partial_name.include?('/')
          pieces = partial_name.split('/')
          partial_name = pieces.pop
          modules = pieces
        end

        partial = File.join(current_file.rails_root, 'app', 'views', modules, "_#{partial_name}.html.erb")
        TextMate.open(partial)

      # Example: render :action => 'login'
      when /render[\s\(].*:action\s*=>\s*['"](.+?)['"]/
        action = $1
        if current_file.file_type == :controller
          current_file.buffer.line_number = 0
          if search = current_file.buffer.find { /def\s+#{action}\b/ }
            TextMate.open(current_file, search[0])
          end
        else
          puts "Don't know where to go when rendering an action from outside a controller"
          exit
        end

      # Example: redirect_to :action => 'login'
      when /(redirect_to|redirect_back_or_default)[\s\(]/
        controller = action = nil
        controller = $1 if TextMate.current_line =~ /.*:controller\s*=>\s*['"](.+?)['"]/
        action = $1 if TextMate.current_line =~ /.*:action\s*=>\s*['"](.+?)['"]/

        unless current_file.file_type == :controller
          puts "Don't know where to go when redirecting from outside a controller"
          exit
        end

        if controller.nil?
          controller_file = current_file
        else
          # Check for modules
          if controller.include?('/')
            pieces = controller.split('/')
            controller = pieces.pop
            modules = pieces
          end
          other_path = File.join(current_file.rails_root, 'app', 'controllers', modules, "#{controller}_controller.rb")
          controller_file = RailsPath.new(other_path)
        end

        if search = controller_file.buffer.find(:direction => :backward) { /def\s+#{action}\b/ }
          TextMate.open(controller_file, search[0])
        else
          puts "Couldn't find the #{action} action inside '#{controller_file.basename}'"
          exit
        end

      # Example: <script src="/javascripts/controls.js">
      when /\<script.+src=['"](.+\.js)['"]/
        javascript = $1
        if javascript =~ %r{^https?://}
          TextMate.open_url javascript
        else
          full_path = File.join(current_file.rails_root, 'public', javascript)
          TextMate.open full_path
        end

      # Example: <%= javascript_include_tag 'general' %>
      # require_javascript is used by bundled_resource plugin
      when /(require_javascript|javascript_include_tag)\b/
        if match = TextMate.current_line.unstringify_hash_arguments.find_nearest_string_or_symbol(TextMate.column_number)
          javascript = match[0]
          javascript += '.js' if not javascript =~ /\.js$/
          # If there is no leading slash, assume it's a js from the public/javascripts dir
          public_file = javascript[0..0] == "/" ? javascript[1..-1] : "javascripts/#{javascript}"
          TextMate.open File.join(current_file.rails_root, 'public', public_file)
        else
          puts "No javascript identified"
        end

      # Example: <link href="/stylesheets/application.css">
      # Example: @import url(/stylesheets/conferences.css);
      when /\<link.+href=['"](.+\.css)['"]/, /\@import.+url\((.+\.css)\)/
        stylesheet = $1
        if stylesheet =~ %r{^https?://}
          TextMate.open_url stylesheet
        else
          full_path = File.join(current_file.rails_root, 'public', stylesheet[1..-1])
          TextMate.open full_path
        end

      # Example: <%= stylesheet_link_tag 'application' %>
      when /(require_stylesheet|stylesheet_link_tag)\b/
        if match = TextMate.current_line.unstringify_hash_arguments.find_nearest_string_or_symbol(TextMate.column_number)
          stylesheet = match[0]
          stylesheet += '.css' if not stylesheet =~ /\.css$/
          # If there is no leading slash, assume it's a js from the public/javascripts dir
          public_file = stylesheet[0..0] == "/" ? stylesheet[1..-1] : "stylesheets/#{stylesheet}"
          TextMate.open File.join(current_file.rails_root, 'public', public_file)
        else
          puts "No stylesheet identified"
        end

      else
        puts "No 'go to file' directives found on this line."
        # Do nothing -- beep?
    end    
  end
  
  protected
  
  # Returns the rails_path of the newly created file plus the position 
  # (zero based) in the file where to place the caret after opening the 
  # new file. Returns nil when no new file is created.
  def self.create_file(rails_path, choice)       
    return nil if rails_path.exists?
    if choice == :view
      filename = TextMate::UI.request_string(
        :title => "View File Not Found", 
        :default => rails_path.basename,
        :prompt => "Enter the name of the new view file:",
        :button1 => 'Create'
      )
      return nil if !filename
      rails_path = RailsPath.new(File.join(rails_path.dirname, filename))
      rails_path.touch
      return [rails_path, 0, 0]
    end
    
    unless TextMate::UI.request_confirmation(
      :button1 => "Create",
      :button2 => "Cancel",
      :title => "Missing #{rails_path.basename}",
      :prompt => "Create missing #{rails_path.basename}?"
    )
      return nil
    end

    generated_code, openatline, openatcol = case choice
    when :model
      ["class #{Inflector.singularize rails_path.controller_name.camelize} < ActiveRecord::Base\n\nend", 1, 0]
    when :controller 
      ["class #{rails_path.controller_name.camelize}Controller < ApplicationController\n\nend", 1, 0]
    when :helper
      ["module #{rails_path.controller_name.camelize}Helper\n\nend", 1, 0]
    when :unit_test
      ["require File.dirname(__FILE__) + '/../test_helper'

class #{Inflector.singularize(rails_path.controller_name).camelize}Test < ActiveSupport::TestCase
 # Replace this with your real tests.
 def test_truth
   assert true
 end
end", 3, 0]   
    when :functional_test
      ["require File.dirname(__FILE__) + '/../test_helper'

class #{rails_path.controller_name.camelize}ControllerTest < ActionController::TestCase     

end", 3, 0]
    end

    rails_path.touch
    rails_path.append generated_code if generated_code
    return [rails_path, openatline, openatcol]
  end
    
end