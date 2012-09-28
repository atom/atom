#!/usr/bin/env ruby
# encoding: utf-8

require "#{ENV['TM_SUPPORT_PATH']}/lib/progress"
TextMate.call_with_progress(:title => "Contacting database", :message => "Fetching database schema…") do

  project = ENV['TM_PROJECT_DIRECTORY']
  word = ENV['TM_CURRENT_WORD']

  require "#{project}/config/boot"
  require "#{project}/config/environment"

  if word.blank?
    STDOUT << "Place cursor on class name (or variation) to show its schema"
    exit
  end

  klass = word.camelcase.singularize.constantize rescue nil
  if klass and klass.class == Class and klass.ancestors.include?(ActiveRecord::Base)
    columns = klass.columns_hash

    data = []
    data += [%w[column primary sql_type default]]
    data += [%w[------ ------- -------- -------]]
    data += columns.collect { |col, attrs| [col, attrs.primary.to_s, attrs.sql_type.to_s, attrs.default.to_s] }

    STDOUT << data.inject('') do |output, array|
      output + array.inject('') { |row_str, value| row_str + value.ljust(20) } + "\n"
    end
  elsif klass and klass.class == Class and not klass.ancestors.include?(ActiveRecord::Base)
    STDOUT << "'#{word}' is not an Active Record derived class"
  else
    STDOUT << "'#{word}' was not recognised as a class"
  end

end