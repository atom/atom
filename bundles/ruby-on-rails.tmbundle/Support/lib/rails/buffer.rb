# Copyright:
#   (c) 2006 syncPEOPLE, LLC.
#   Visit us at http://syncpeople.com/
# Author: Duane Johnson (duane.johnson@gmail.com)
# Description:
#   Makes analyzing of a Rails path + filename easier.

require 'rails/text_mate'
require 'rails/misc'

# Stores lines of text
class Buffer
  # The actual lines of the text file
  attr_reader :lines
  # State of caret positions (both 0-based indexes)
  attr_accessor :line_number, :column_number
  # Stack for remembering caret positions
  attr_reader :stack

  # Init from a String or Buffer object
  def initialize(buffer, line_number = nil, column_number = nil)
    self.text = buffer
    @line_number   = line_number   || TextMate.line_number
    @column_number = column_number || TextMate.column_number
    @stack = []
  end

  # Init from a String (filename) or FilePath
  def self.new_from_file(filepath, line_number = nil, column_number = nil)
    # In case it's a RailsPath, get the string representing the filepath
    filepath = filepath.filepath if filepath.respond_to?(:filepath)
    new(IO.read(filepath, line_number, column_number))
  end

  def index
    @lines.slice(0...line_number).join.length
  end

  def current_line
    lines[line_number]
  end

  def push_position
    @stack.push [@line_number, @column_number]
  end

  def pop_position
    @line_number, @column_number = @stack.pop
  end

  def to_a
    @lines
  end

  def text
    @text ||= lines.join
  end

  def text=(buffer)
    @text = buffer.gsub("\r\n", "\n")
    @lines = @text.to_a
  end

  def =~(other)
    text =~ other
  end

  # Searches a region of the buffer, lines :from to :to
  # Accepts a block which can evaluate to either true/false indication of a line match,
  # or a Regexp indicating that the line must match the regexp for the line to match.
  # An optional :direction of :backward is also accepted if the search is to be reversed.
  def find(options = {}, &block)
    options = {:direction => :forward}.update(options)

    # Use some sensible defaults if just a direction is given
    if direction = options[:direction] == :forward
      from = options[:from] || line_number
      to   = options[:to]   || lines.size - 1
      from, to = to, from if from > to
      direction = 1
    else
      from = options[:from] || 0
      to   = options[:to]   || line_number
      from, to = to, from if from < to
      direction = -1
    end

    from.step(to, direction) do |i|
      value = yield(lines[i])
      value = lines[i].scan(value) if value.is_a? Regexp
      return [i, value].flatten.compact if value.first
    end
    return nil
  end

  # Search for the nearest "def [method]" declaration
  def find_method(options = {})
    options = {:direction => :backward}.update(options)
    find(options) { %r{def\s+(\w+)} }
  end

  # Search for the nearest "wants." declaration within a "respond_to" section.
  def find_respond_to_format
    m = find_method
    return nil if m.nil?
    from, wants = find(:direction => :backward, :from => m.first) { %r{\brespond_to\s.+\|\s*(\w+)\s*\|} }
    return nil if wants.nil?
    options = {:direction => lines[from] == current_line ? :forward : :backward, :from => from}
    find(options) { Regexp.new(wants + '\.(\w+)') }
  end

  def find_nearest_string_or_symbol(current_line = current_line)
    current_line.find_nearest_string_or_symbol(column_number)
  end

end
