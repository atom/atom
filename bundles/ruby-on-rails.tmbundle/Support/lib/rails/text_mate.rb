# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Helper module for accesing TextMate facilities such as environment variables.

require 'uri'
module TextMate
  class <<self
    def open_url(url)
      `open "#{url}"`
    end

    # Open a file in textmate using the txmt:// protocol.  Uses 0-based line and column indices.
    def open(filename, line_number = nil, column_number = nil)
      filename = filename.filepath if filename.is_a? RailsPath
      options = []
      options << "url=file://#{URI.escape(filename)}"
      options << "line=#{line_number + 1}" if line_number
      options << "column=#{column_number + 1}" if column_number
      open_url "txmt://open?" + options.join("&")
    end

    # Always return something, or nil, for selected_text
    def selected_text
      env(:selected_text)
    end

    # Make line_number 0-base index
    def line_number
      env(:line_number).to_i - 1
    end

    # Make column_number 0-base as well
    def column_number
      env(:column_number).to_i - 1
    end

    def project_directory
      env(:project_directory)
    end

    def env(var)
      ENV['TM_' + var.to_s.upcase]
    end

    # Forward to the TM_* environment variables if method is missing.  Some useful variables include:
    #   selected_text, current_line, column_number, line_number, support_path
    def method_missing(method, *args)
      if value = env(method)
        return value
      else
        super(method, *args)
      end
    end

    def cocoa_dialog_command
      "#{support_path}/bin/CocoaDialog.app/Contents/MacOS/CocoaDialog"
    end

    # See http://cocoadialog.sourceforge.net/documentation.html for documentation
    def cocoa_dialog(command, options = {})
      options_list = []
      options.each_pair do |k, v|
        k = k.to_s.gsub('_', '-')
        value = v.is_a?(Array) ? %Q{"#{v.join('" "')}"} : "\"#{v}\""
        if v
          if v.is_a? TrueClass
            options_list << "--#{k}"
          else
            options_list << "--#{k} #{value}"
          end
        end
      end
      dialog_command = "\"#{cocoa_dialog_command}\" #{command} #{options_list.join(' ')}"
      # $logger.debug "Dialog command: #{dialog_command}"
      `#{dialog_command}`.to_a.map { |v| v.strip }
    end

    def choose(text, choices = ["none"], options = {})
      options = {:title => "Choose", :text => text, :items => choices, :button1 => 'Ok', :button2 => 'Cancel'}.update(options)
      button, choice = cocoa_dialog('dropdown', options)
      if button == '1'
        return choice.strip.to_i
      else
        return nil
      end
    end
  end
end
