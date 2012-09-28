#!/usr/bin/env ruby
#
# Copyright (c) 2006 Sami Samhuri
# Distributed under the MIT license
#
# Inserts a migration snippet into 2 places in the document, one
# piece in self.up and one in self.down.

snippets = {
  'rename_column' =>
    { :up   => 'rename_column :${1:table_name}, :${2:column_name}, :${3:new_column_name}$0',
      :down => 'rename_column :$1, :$3, :$2' },

  'rename_column_continue' =>
    { :up   => 'rename_column :${1:table_name}, :${2:column_name}, :${3:new_column_name}
mncc$0',
      :down => 'rename_column :$1, :$3, :$2' },

  'rename_table' =>
    { :up   => 'rename_table :${1:old_table_name}, :${2:new_table_name}$0',
      :down => 'rename_table :$2, :$1' },

  'rename_table_continue' =>
    { :up   => 'rename_table :${1:old_table_name}, :${2:new_table_name}
mntc$0',
      :down => 'rename_table :$2, :$1' },

  'add_remove_column' =>
    { :up   => 'add_column :${1:table_name}, :${2:column_name}, :${3:string}$0',
      :down => 'remove_column :$1, :$2' },

  'add_remove_column_continue' =>
    { :up   => 'add_column :${1:table_name}, :${2:column_name}, :${3:string}
marcc$0',
      :down => 'remove_column :$1, :$2' },

  'create_drop_table' =>
    { :up   => 'create_table :${1:table_name}, :force => true do |t|
  t.$0
  t.timestamps
end',
      :down => 'drop_table :$1' },

  'change_change_table' =>
    { :up   => 'change_table :${1:table_name} do |t|
  t.$0
end',
      :down => 'change_table :$1 do |t|
end' },

  'add_remove_index' =>
    { :up   => 'add_index :${1:table_name}, :${2:column_name}$0',
      :down => 'remove_index :$1, :$2' },

  'add_remove_unique_index' =>
    { :up   => 'add_index :${1:table_name}, ${2:[:${3:column_name}${4:, :${5:column_name}}]}, :unique => true$0',
      :down => 'remove_index :$1, :column => $2' },

  'add_remove_named_index' =>
    { :up   => 'add_index :${1:table_name}, [:${2:column_name}${3:, :${4:column_name}}], :name => "${5:index_name}"${6:, :unique => true}$0',
      :down => 'remove_index :$1, :name => :$5' }
}

def indent(code)
  spaces = ' ' * (2 * ENV['TM_TAB_SIZE'].to_i)
  lines = code.to_a.collect { |s| spaces + s }
  lines.to_s + "\n"
end

def insert_migration(snippet, text)
  lines = text.to_a

  up_code = indent(snippet[:up])
  down_code = indent(snippet[:down])

  # insert the self.up part of the snippet
  lines[0] = up_code

  # find the beginning of self.down and insert down code, this is hardly robust.
  # assuming self.down is after self.up in the class
  lines.each_with_index do |line, i|
    if line =~ /^\s*def\s+self\.down\b/
      lines[i, 1] = [lines[i], down_code]
      break
    end
  end
  lines.to_s
end

snippet = ARGV.shift

# escape chars that are special in snippets
text = STDIN.read.gsub('[\$\`\\]', '\\\\\1')

if snippets.has_key? snippet
  output = insert_migration(snippets[snippet], text)
else
  # return the unmodified text
  output = text
end

print output