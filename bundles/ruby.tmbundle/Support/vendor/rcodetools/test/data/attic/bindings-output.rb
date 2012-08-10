
require 'test/unit'

class TestFoo < Test::Unit::TestCase
  def setup
    @o = []
  end

  def test_foo
    a = 1
    b = a
    assert_equal a, b
    assert_equal 1, b
  end

  def test_arr
    last = 1
    @o << last
    assert_equal last, @o.last
    assert_equal 1, @o.last
  end

  def test_bar
    a = b = c = 1
    d = a
    assert_equal a, d
    assert_equal b, d
    assert_equal c, d
    assert_equal 1, d
  end
end
