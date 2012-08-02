
class X
  Y = Struct.new(:a)
  def foo(b); b ? Y.new(2) : 2 end
  def bar; raise "No good" end
  def baz; nil end
  def fubar(x); x ** 2.0 + 1 end
  def babar; [1,2] end
  A = 1
  A = 1 # !> already initialized constant A
  def difftype() [1, "s"] end
end


require 'test/unit'
class Test_X < Test::Unit::TestCase
  def setup
    @o = X.new
  end

  def test_foo
    assert_kind_of(X::Y, @o.foo(true))
    assert_equal("#<struct X::Y a=2>", @o.foo(true).inspect)
    assert_equal(2, @o.foo(true).a)
    assert_equal(2, @o.foo(false))
  end
  
  def test_bar
    assert_raise(RuntimeError){@o.bar}
  end

  def test_baz
    assert_nil(@o.baz)
  end

  def test_babar
    assert_equal([1, 2], @o.babar)
  end

  def test_fubar
    assert_in_delta(101.0, @o.fubar(10), 0.0001)
  end

  def test_difftype
    for x in @o.difftype
      #xmpfilter: WARNING!! extra values ignored
      assert_equal(1, x)
    end
  end

end

