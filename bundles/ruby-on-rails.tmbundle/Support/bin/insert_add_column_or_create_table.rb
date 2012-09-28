#!/usr/bin/env ruby
require ENV['TM_BUNDLE_SUPPORT'] + '/lib/rails_bundle_tools'

def prepend(text, prefix)
  text.to_a.map { |line| prefix + line }.join
end

def unprepend(text, prefix)
  text.to_a.map { |line| line.index(prefix) == 0 ? line.sub(prefix, '') : line }.join
end

buffer = Buffer.new(STDIN.read, 0, 0)

table_name = column_name = nil
case buffer.lines[0]
when /remove_column\s+:(\w+),\s*:(\w+)/
  table_name, column_name = $1, $2
when /drop_table\s+:(\w+)/
  table_name = $1
else
  puts "No table or column name specified. (\"#{buffer.lines[0]}\")"
  TextMate.exit_show_tool_tip
end

# Find 'self.down' method
if self_down = buffer.find { /^(\s*)def\s+self\.down\b/ }
  indentation = self_down[1]

  # Find the matching create_table clause in the schema.rb file
  schema = RailsPath.new('db/schema.rb')
  schema.buffer.line_number = schema.buffer.column_number = 0
  if schema.exists?
    if insert_text = schema.buffer.find { %r{^(\s*)create_table\s+["']#{table_name}['"]} }
      from = insert_text[0] + 1
      insert_text_indentation = insert_text[1]
      insert_text_end = schema.buffer.find(:from => from) { %r{^#{insert_text_indentation}end\b} }

      # If a column is specified, get just the column, not the whole create_table
      if column_name
        to = insert_text_end[0]
        if insert_text = schema.buffer.find { %r{^\s*\w+\.(column|primary_key|string|text|integer|float|decimal|datetime|timestamp|time|date|binary|boolean)\s+['"]#{column_name}['"](.*)$} }
          column_type = ", :#{insert_text[1]}" unless insert_text[1] == "column"
          column_params = insert_text[2]
          insert_text = "add_column :#{table_name}, :#{column_name}#{column_type}#{column_params}\n"

          buffer.lines.insert self_down[0] + 1, prepend(insert_text, indentation + "  ")
        else
          puts "The db/schema.rb does not have a column matching \"#{column_name}\" within create_table \"#{table_name}\"."
          TextMate.exit_show_tool_tip
        end
      else
        insert_text = unprepend(schema.buffer.lines[insert_text[0]..insert_text_end[0]], insert_text_indentation)
        buffer.lines.insert self_down[0] + 1, prepend(insert_text + "\n", indentation + "  ")
      end
      print buffer.lines.join.gsub(/\[press tab twice to generate (create_table|add_column)\]/, "")
    else
      puts "The db/schema.rb does not have a create_table \"#{table_name}\"."
      TextMate.exit_show_tool_tip
    end
  else
    puts "The db/schema.rb file doesn't exist.  Can't insert create_table."
    TextMate.exit_show_tool_tip
  end
else
  puts "No self.down method found in below the caret."
  TextMate.exit_show_tool_tip
end