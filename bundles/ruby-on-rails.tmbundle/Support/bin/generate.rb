#!/usr/bin/env ruby

# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Asks what to generate and what name to use, then runs script/generate.

require 'rails_bundle_tools'
require 'fileutils'
require File.dirname(__FILE__) + "/../lib/rails/generate"

# Look for (created) files and return an array of them
def files_from_generator_output(output, type = 'create')
  output.to_a.map { |line| line.scan(/#{type}\s+([^\s]+)$/).flatten.first }.compact.select { |f| File.exist?(f) and !File.directory?(f) }
end

Generator.setup

if choice = TextMate.choose("Generate:", Generator.names.map { |name| Inflector.humanize name }, :title => "Rails Generator")
  arguments = TextMate::UI.request_string(
    :title => "#{Inflector.humanize Generator.generators[choice].name} Generator", 
    :default => Generator.generators[choice].default_answer,
    :prompt => Generator.generators[choice].question,
    :button1 => 'Generate'
  )

  if arguments
    options = ""

    case choice
    when 0
      options = TextMate::UI.request_string(
        :title => "Scaffold Controller Name", 
        :prompt => "Name the new controller for the scaffold:",
        :button1 => 'Continue'
      )
      options = "'#{options}'"
    when 1
      options = TextMate::UI.request_string(
        :title => "Controller Actions", 
        :default => "index new create edit update destroy",
        :prompt => "List any actions you would like created for the controller:",
        :button1 => 'Create'
      )
    end

    # add the --svn option, if needed
    proj_dir = ENV["TM_PROJECT_DIRECTORY"]
    if proj_dir and File.exist?(File.join(proj_dir, ".svn"))
      options << " --svn"
    end

    rails_root = RailsPath.new.rails_root
    FileUtils.cd rails_root
    command = "script/generate #{Generator.generators[choice].name} #{arguments} #{options}"
    $logger.debug "Command: #{command}"

    output = ruby(command)
    $logger.debug "Output: #{output}"
    TextMate.rescan_project
    files = files_from_generator_output(output)
    files.each { |f| TextMate.open(File.join(rails_root, f)) }
    TextMate::UI.simple_notification(
      :title => 'Generator Complete',
      :summary => "Done generating #{Generator.generators[choice].name}",
      :log => output
    )
  end
end
