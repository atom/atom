#!/usr/bin/env ruby
# encoding: utf-8

# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Creates a partial from the selected text (asks for the partial name)
#   and replaces the text with a "render :partial => [partial_name]" erb fragment.

require 'rails_bundle_tools'

current_file = RailsPath.new

# Make sure we're in a view file
unless current_file.file_type == :view
  TextMate.exit_show_tool_tip("The ‘create partial from selection’ action works within view files only.")
end

# If text is selected, create a partial out of it
if TextMate.selected_text
  partial_name = TextMate::UI.request_string(
    :title => "Create a partial from the selected text", 
    :default => "partial",
    :prompt => "Name of the new partial: (omit the _ and .html.erb)",
    :button1 => 'Create'
  )

  if partial_name
    path = current_file.dirname
    partial = File.join(path, "_#{partial_name}.html.erb")

    # Create the partial file
    if File.exist?(partial)
      unless TextMate::UI.request_confirmation(
        :button1 => "Overwrite",
        :button2 => "Cancel",
        :title => "The partial file already exists.",
        :prompt => "Do you want to overwrite it?"
      )
        TextMate.exit_discard
      end
    end

    file = File.open(partial, "w") { |f| f.write(TextMate.selected_text) }
    TextMate.rescan_project

    # Return the new render :partial line
    print "<%= render :partial => '#{partial_name}' %>\n"
  else
    TextMate.exit_discard
  end
else
  # Otherwise, toggle inline partials if they exist

  text = ""
  partial_block_re =
    /<!--\s*\[\[\s*Partial\s'(.+?)'\sBegin\s*\]\]\s*-->\n(.+)<!--\s*\[\[\s*Partial\s'\1'\sEnd\s*\]\]\s*-->\n/m

  # Inline partials exist?
  if current_file.buffer =~ partial_block_re
    text = current_file.buffer.text
    while text =~ partial_block_re
      partial_name, partial_text = $1, $2
      File.open(partial_name, "w") { |f| f.write $2 }
      text.sub! partial_block_re, ''
    end
  else
  # See if there are any render :partial statements to expand
    current_file.buffer.lines.each_with_index do |line, i|
      text << line
      if line =~ /render[\s\(].*:partial\s*=>\s*['"](.+?)['"]/
        partial_name = $1
        modules = current_file.modules + [current_file.controller_name]

        # Check for absolute path to partial file
        if partial_name.include?('/')
          pieces = partial_name.split('/')
          partial_name = pieces.pop
          modules = pieces
        end

        partial = File.join(current_file.rails_root, 'app', 'views', modules, "_#{partial_name}.html.erb")

        text << "<!-- [[ Partial '#{partial}' Begin ]] -->\n"
        text << IO.read(partial).gsub("\r\n", "\n")
        text << "<!-- [[ Partial '#{partial}' End ]] -->\n"
      end
    end
  end
  print text
  TextMate.exit_replace_document
end