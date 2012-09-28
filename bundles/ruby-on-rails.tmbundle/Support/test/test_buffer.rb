require File.dirname(__FILE__) + '/test_helper'

require 'text_mate_mock'
require 'rails/buffer'

TextMate.line_number = '1'
TextMate.column_number = '1'
TextMate.selected_text = <<-END
def my_method
  puts 'hi'
  # some comment, 'hi'
end

def my_other_method
  x = y + z
  # another comment
end

def index
  respond_to do |wants|
    wants.html { }
    wants.js   { }
    wants.css  { }
  end
  respond_to { | wacky |
    wacky.wackier { }
  }
end

def edit
end
END

class BufferTest < Test::Unit::TestCase
  def test_find
    b = Buffer.new(TextMate.selected_text)
    match = b.find { /'(.+)'/ }
    assert_equal [1, "hi"], match

    match = b.find(:from => 2, :to => 1, :direction => :backward) { /'(.+)'/ }
    assert_equal [2, "hi"], match

    match = b.find(:from => 2, :to => 1, :direction => :backward) { /my_method/ }
    assert_nil match
  end

  def test_find_method
    b = Buffer.new(TextMate.selected_text)
    assert_equal [0, 'my_method'], b.find_method

    b.line_number = 4
    assert_equal [0, 'my_method'], b.find_method

    b.line_number = 5
    assert_equal [5, 'my_other_method'], b.find_method
  end

  def test_find_respond_to_format
     b = Buffer.new(TextMate.selected_text)
     assert_equal nil, b.find_respond_to_format
     b.line_number = 10
     assert_equal nil, b.find_respond_to_format
     b.line_number = 11
     assert_equal [12, 'html'], b.find_respond_to_format
     b.line_number = 12
     assert_equal [12, 'html'], b.find_respond_to_format
     b.line_number = 13
     assert_equal [13, 'js'], b.find_respond_to_format
     b.line_number = 14
     assert_equal [14, 'css'], b.find_respond_to_format
     b.line_number = 15
     assert_equal [14, 'css'], b.find_respond_to_format
     b.line_number = 16
     assert_equal [17, 'wackier'], b.find_respond_to_format
     b.line_number = 17
     assert_equal [17, 'wackier'], b.find_respond_to_format
     b.line_number = 18
     assert_equal [17, 'wackier'], b.find_respond_to_format
     b.line_number = 19
     assert_equal [17, 'wackier'], b.find_respond_to_format
     b.line_number = 20
     assert_equal [17, 'wackier'], b.find_respond_to_format
     b.line_number = 21
     assert_equal nil, b.find_respond_to_format
  end

  def test_find_multiple_matches
    b = Buffer.new(TextMate.selected_text)
    match = b.find { /^\s*x = (\w) \+ (\w)\s*$/ }
    assert_equal [6, 'y', 'z'], match

    b = Buffer.new(TextMate.selected_text)
    match = b.find { /^\s*x = (\w) \+ (\w)(\w?)\s*$/ }
    assert_equal [6, 'y', 'z', ''], match
  end

  def test_find_nearest_string_or_symbol
    b = Buffer.new "String :with => 'strings', :and, :symbols"
    match = b.find_nearest_string_or_symbol
    assert_equal ["with", 8], match

    b.column_number = 8
    match = b.find_nearest_string_or_symbol
    assert_equal ["with", 8], match

    b.column_number = 25
    match = b.find_nearest_string_or_symbol
    assert_equal ["strings", 17], match

    b.column_number = 37
    match = b.find_nearest_string_or_symbol
    assert_equal ["symbols", 34], match

    b = Buffer.new "String without symbols or strings"
    match = b.find_nearest_string_or_symbol
    assert_nil match
  end
end