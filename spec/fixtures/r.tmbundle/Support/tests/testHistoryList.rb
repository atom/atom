require 'test/unit'
require '../lib/historyList.rb'
class TestHistoryList < Test::Unit::TestCase
  def setup
    @sample = File.read("historyTestFile.Rconsole")
    test_init
  end
  def test_init
    assert_nothing_raised() { @list = HistoryList.new(@sample) }
    assert_not_nil(@list)
    assert_not_nil(@list.list)
    assert_not_nil(@list.last_line)
    assert_equal(@sample, @list.text + "> ")
  end
  def test_uniqueness
    assert_equal(3, @list.list.length)
    assert_equal(["second command","first command","third command"],@list.list)
  end
  def test_last_line
    assert_equal("> ",@list.last_line)
  end
  def test_add_line
    assert_equal(@sample + "hey", @list.add_line("> hey"))
  end
  def test_next_item
    assert_equal("first command", @list.next_item("second command"))
    assert_equal("first command", @list.next_item(">second command"))
    assert_equal("third command", @list.next_item("first command"))
    assert_equal("third command", @list.next_item("> first command"))
    assert_equal(nil, @list.next_item("third command"))
    assert_equal("second command", @list.next_item(" "))
    assert_equal("second command", @list.next_item("> "))
    assert_equal("second command", @list.next_item(""))
    assert_equal("second command", @list.next_item(nil))
  end
  def test_previous_item
    assert_equal("second command", @list.previous_item("first command"))
    assert_equal("second command", @list.previous_item(">first command"))
    assert_equal("first command", @list.previous_item("third command"))
    assert_equal("first command", @list.previous_item("> third command"))
    assert_equal(nil, @list.previous_item("second command"))
    assert_equal("third command", @list.previous_item(" "))
    assert_equal("third command", @list.previous_item("> "))
    assert_equal("third command", @list.previous_item(""))
    assert_equal("third command", @list.previous_item(nil))
  end
  def test_move_commands
    assert_equal(@sample + "second command", @list.move_down)
    assert_equal(@sample + "third command",@list.move_up)
    assert_equal(@sample,HistoryList.move_down(@list.move_up))
  end
end