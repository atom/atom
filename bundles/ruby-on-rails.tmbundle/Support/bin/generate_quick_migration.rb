#!/usr/bin/env ruby

# Copyright:
#   (c) 2006 InquiryLabs, Inc.
#   Visit us at http://inquirylabs.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Generates a migration file from the selection or current word.  This is much faster than calling upon
#   Rails' built-in generate migration code.

require 'rails_bundle_tools'
require 'fileutils'

selection = TextMate::UI.request_string(
  :title => "Quick Migration Generator", 
  :default => "CreateUserTable",
  :prompt => "Name the new migration:",
  :button1 => 'Create'
)

if selection.size < 3 or selection.size > 255
  print "Please highlight the name of the migration you want to create"
  TextMate.exit_show_tool_tip
end

rails_root = RailsPath.new.rails_root
migration_dir = File.join(rails_root, "db", "migrate")
files = Dir.glob(File.join(migration_dir, "[0-9][0-9][0-9]_*"))
if files.empty?
  number = "001"
else
  number = File.basename(files[-1])[0..2].succ
end

if selection =~ /^[a-z]/ or selection.include?("_")
  # The selected text is an underscored word
  underscored = selection
  camelized = underscored.camelize
else
  # The selected text is a camelized word
  camelized = selection
  underscored = camelized.underscore
end

generated_code = <<-RUBY
class #{camelized} < ActiveRecord::Migration
  def self.up
    mtab
  end

  def self.down
  end
end
RUBY

FileUtils.mkdir_p migration_dir
new_migration_filename = File.join(migration_dir, number + "_" + underscored + ".rb")
File.open(new_migration_filename, "w") { |f| f.write generated_code }
TextMate.rescan_project
TextMate.open(new_migration_filename, 2, 8)
