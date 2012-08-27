
require 'test/unit'

class TestFoo < Test::Unit::TestCase
  def setup
    @o = []
  end

  def test_foo
    a = 1
    b = a
    b                                              # =>
  end

  def test_arr
    last = 1
    @o << last
    @o.last                                        # =>
  end

  def test_bar
    a = b = c = 1
    d = a
    d                                              # =>
  end
end
