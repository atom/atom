#!/usr/bin/env ruby

# Copyright:
#   (c) 2006 InquiryLabs, Inc.
#   Visit us at http://inquirylabs.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Retrieves plugin data from agilewebdevelopment.com and allows you to install directly.

if RUBY_VERSION =~ /^1\.6\./ then
  puts <<-HTML
    <p>Sorry, but this function requires Ruby 1.8.</p>
    <p>If you do have Ruby 1.8 installed (default for Tiger users) then you need to setup the path variable in <tt> ~/.MacOSX/environment.plist</tt>.</p>
    <p>For detailed instructions see <a href="http://macromates.com/textmate/manual/shell_commands#search_path">the manual</a> (scroll down to the paragraph starting with <em>Important</em>.)</p>
    HTML
  abort
end

require ENV['TM_SUPPORT_PATH'] + '/lib/escape' # we use e_sh in the rhtml template
require 'rails_bundle_tools'
require "erb"
include ERB::Util
#require 'fileutils'

root = RailsPath.new.rails_root

script = File.join(root, "script", "plugin")
enable_install = true
unless File.exist? script
  TextMate::UI.alert(:warning, "Plugin Script Not Found", "The 'plugin' script was not found in #{script}. Plugins will not be able to be installed.", 'OK')
  enable_install = false
end

$tags = [
  { :label => "FIXME",   :color => "#A00000", :regexp => /FIX ?ME[\s,:]+(\S.*)$/i },
  { :label => "TODO",    :color => "#CF830D", :regexp => /TODO[\s,:]+(\S.*)$/i    },
  { :label => "CHANGED", :color => "#008000", :regexp => /CHANGED[\s,:]+(\S.*)$/  },
  { :label => "RADAR",   :color => "#0090C8", :regexp => /(.*<)ra?dar:\/(?:\/problem|)\/([&0-9]+)(>.*)$/, :trim_if_empty => true },
]

template_file = "#{TextMate.bundle_support}/templates/list_plugins.rhtml"
print ERB.new(File.open(template_file), 0, '<>').result
