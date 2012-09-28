# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Makes analyzing of a Rails path + filename easier.

require 'rails/misc'
require 'rails/text_mate'
require 'rails/buffer'
require 'rails/inflector'
require 'fileutils'

module AssociationMessages
  @@associations = {
    :controller => [:functional_test, :helper, :model, :javascript, :stylesheet, :fixture],
    :helper => [:controller, :model, :unit_test, :functional_test, :javascript, :stylesheet, :fixture],
    :view => [:controller, :javascript, :stylesheet, :helper, :model],
    :model => [:unit_test, :functional_test, :controller, :helper, :fixture],
    :fixture => [:unit_test, :functional_test, :controller, :helper, :model],
    :functional_test => [:controller, :helper, :model, :unit_test, :fixture],
    :unit_test => [:model, :controller, :helper, :functional_test, :fixture],
    :javascript => [:helper, :controller],
    :stylesheet => [:helper, :controller]
  }

  # Make associations hash publicly available to each object
  def associations; self.class.class_eval("@@associations") end

  # Return associated_with_*? methods
  def method_missing(method, *args)
    case method.to_s
    when /^associated_with_(.+)\?$/
      return associations[$1.to_sym].include?(file_type)
    else
      super(method, *args)
    end
  end

  def best_match
    return nil if associations[file_type].nil?
    return :view if file_type == :controller && action_name
    associations[file_type].each { |x| return x if rails_path_for(x).exists? }
    return associations[file_type].first
  end
end

class RailsPath
  attr_reader :filepath
  attr_reader :path_name, :file_name, :content_type, :extension

  include AssociationMessages

  def initialize(filepath = TextMate.filepath)
    if filepath[0..0] == '/'
      # Absolute file, treat as is
      @filepath = filepath
    else
      # Relative file, prepend rails_root
      @filepath = File.join(rails_root, filepath)
    end

    # Put parts into instance variables to make retrieval more uniform.
    parse_file_parts
  end

  def buffer
    @buffer ||= Buffer.new_from_file(self)
  end

  def exists?
    File.file?(@filepath)
  end

  def basename
    File.basename(@filepath)
  end

  def dirname
    File.dirname(@filepath)
  end

  # Make sure the file exists by creating it if it doesn't
  def touch
    if !exists?
      FileUtils.mkdir_p dirname
      FileUtils.touch @filepath
    end
  end

  def append(str)
    File.open(@filepath, "a") { |f| f.write str }
  end

  def controller_name
    name = @file_name
    # Remove extras
    case file_type
    when :controller then name.sub!(/_controller$/, '')
    when :helper     then name.sub!(/_helper$/, '')
    when :unit_test  then name.sub!(/_test$/, '')
    when :view       then name = dirname.split('/').pop
    when :functional_test then name.sub!(/_controller_test$/, '')
    else
      if !File.file?(File.join(rails_root, stubs[:controller], '/', name + '_controller.rb'))
        name = Inflector.pluralize(name)
      end
    end
    return name
  end

  def action_name
    name =
      case file_type
      when :controller, :model
        buffer.find_method(:direction => :backward).last rescue nil
      when :view
        basename
      when :functional_test
        buffer.find_method(:direction => :backward).last.sub('^test_', '')
      else nil
      end

    return parse_file_name(name)[:file_name] rescue nil # Remove extension
  end

  def respond_to_format
    return nil unless file_type == :controller
    buffer.find_respond_to_format
  end

  def rails_root
    return TextMate.project_directory
    # TODO: Look for the root_indicators inside TM_PROJECT_DIRECTORY and return nil if not found

    #self.class.root_indicators.each do |i|
    #  if index = @filepath.index(i)
    #    return @filepath[0...index]
    #  end
    #end
  end

  # This is used in :file_type and :rails_path_for_view
  VIEW_EXTENSIONS = %w( erb builder rhtml rxhtml rxml rjs haml )

  def file_type
    return @file_type if @file_type

    @file_type =
      case @filepath
      when %r{/controllers/(.+_controller\.(rb))$}      then :controller
      when %r{/controllers/(application\.(rb))$}        then :controller
      when %r{/helpers/(.+_helper\.rb)$}                then :helper
      when %r{/views/(.+\.(#{VIEW_EXTENSIONS * '|'}))$} then :view
      when %r{/models/(.+\.(rb))$}                      then :model
      when %r{/.+/fixtures/(.+\.(yml|csv))$}            then :fixture
      when %r{/test/functional/(.+\.(rb))$}             then :functional_test
      when %r{/test/unit/(.+\.(rb))$}                   then :unit_test
      when %r{/public/javascripts/(.+\.(js))$}          then :javascript
      when %r{/public/stylesheets/(?:sass/)?(.+\.(css|sass))$}  then :stylesheet
      else nil
      end
    # Store the tail (modules + file) after the regexp
    # The first set of parens in each case will become the "tail"
    @tail = $1
    # Store the file extension
    @extension = $2
    return @file_type
  end

  def tail
    # Get the tail if it's not set yet
    file_type unless @tail
    return @tail
  end

  def extension
    # Get the extension if it's not set yet
    file_type unless @extension
    return @extension
  end

  # View file that does not begin with _
  def partial?
    file_type == :view and basename !~ /^_/
  end

  def modules 
    return nil if tail.nil? 
    if file_type == :view
      tail.split('/').slice(0...-2)
    else
      tail.split('/').slice(0...-1)
    end
  end

  def controller_name_possibles_modified_for(type)
    case type
    when :controller
      if controller_name == 'application'
        controller_name
      else
        [Inflector.pluralize(controller_name), Inflector.singularize(controller_name)].
         map { |name| name + '_controller' }
      end
    when :helper     then controller_name + '_helper'
    when :functional_test then controller_name + '_controller_test'
    when :unit_test  then Inflector.singularize(controller_name) + '_test'
    when :model      then Inflector.singularize(controller_name)
    when :fixture    then Inflector.pluralize(controller_name)
    else controller_name
    end
  end

  def select_controller_name(type, base_path, extn)
    controller_names = controller_name_possibles_modified_for(type)
    if controller_names.is_a?(Array)
      for name in controller_names
        return name if File.exists?(File.join(base_path, name + extn))
      end
      controller_names = controller_names.first
    end
    controller_names
  end
  
  def default_extension_for(type, view_format = nil)
    case type
    when :javascript then ENV['RAILS_JS_EXT'] || '.js'
    when :stylesheet then ENV['RAILS_CSS_EXT'] || (wants_haml ? '.sass' : '.css')
    when :view       then                    
      view_format = :html if view_format.nil?
      case view_format.to_sym
      when :xml, :rss, :atom then ".#{view_format}.builder"
      when :js  then '.js.rjs'
      else 
        rails_view_ext = ENV['RAILS_VIEW_EXT'] || (wants_haml ? '.haml' : '.erb')
        ".#{view_format}#{rails_view_ext}"
      end
    when :fixture    then '.yml'
    else '.rb'
    end
  end

  def rails_path_for(type)    
    return nil if file_type.nil?
    return rails_path_for_view if type == :view
    if TextMate.project_directory
      base_path = File.join(rails_root, stubs[type], modules)
      extn      = default_extension_for(type)
      file_name = select_controller_name(type, base_path, extn)
      RailsPath.new(File.join(base_path, file_name + extn))
    else
      puts "There needs to be a project associated with this file."
    end
  end

  def rails_path_for_view
    return nil if action_name.nil?
    line, view_format = respond_to_format

    if view_format
      VIEW_EXTENSIONS.each do |ext|
        filename_with_extension = "#{action_name}.#{view_format}.#{ext}"
        existing_view = File.join(rails_root, stubs[:view], modules, controller_name, filename_with_extension)
        return RailsPath.new(existing_view) if File.exist?(existing_view)
      end
    end
    VIEW_EXTENSIONS.each do |ext|
      filename_with_extension = "#{action_name}.#{ext}"
      existing_view = File.join(rails_root, stubs[:view], modules, controller_name, filename_with_extension)
      return RailsPath.new(existing_view) if File.exist?(existing_view)
    end
    default_view = File.join(rails_root, stubs[:view], modules, controller_name, action_name + default_extension_for(:view, view_format))
    return RailsPath.new(default_view)
  end

  def parse_file_parts
    @path_name, @file_name = File.split(@filepath)
    file_part_hash = parse_file_name(@file_name)
    @file_name = file_part_hash[:file_name]
    @content_type = file_part_hash[:content_type]
    @extension = file_part_hash[:extension]
    return [@path_name, @file_name, @content_type, @extension]
  end

  # File name parser that has no side-effects on object state
  def parse_file_name(file_name)
    path_parts = file_name.split('.')
    extension = path_parts.pop if path_parts.length > 1
    content_type = path_parts.pop if path_parts.length > 1
    file_name = path_parts.join('.')
    return {:extension => extension, :content_type => content_type, :file_name => file_name}
  end

  def wants_haml
    @wants_html ||= File.file?(File.join(rails_root, "vendor/plugins/haml/", "init.rb"))
  end

  def stubs
    { :controller => 'app/controllers',
      :model => 'app/models',
      :helper => 'app/helpers/',
      :view => 'app/views/',
      :config => 'config',
      :lib => 'lib',
      :log => 'log',
      :javascript => 'public/javascripts',
      :stylesheet => wants_haml ? 'public/stylesheets/sass' : 'public/stylesheets',
      :functional_test => 'test/functional',
      :unit_test => 'test/unit',
      :fixture => 'test/fixtures'}
  end

  def ==(other)
    other = other.filepath if other.respond_to?(:filepath)
    @filepath == other
  end
end