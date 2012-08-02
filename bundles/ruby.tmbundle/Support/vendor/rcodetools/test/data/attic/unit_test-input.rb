
class X
  Y = Struct.new(:a)
  def foo(b); b ? Y.new(2) : 2 end
  def bar; raise "No good" end
  def baz; nil end
  def fubar(x); x ** 2.0 + 1 end
  def babar; [1,2] end
  A = 1
  A = 1
  def difftype() [1, "s"] end
end


require 'test/unit'
class Test_X < Test::Unit::TestCase
  def setup
    @o = X.new
  end

  def test_foo
    @o.foo(true)   # =>
    @o.foo(true).a # =>
    @o.foo(false)  # =>
  end
  
  def test_bar
    @o.bar         # =>
  end

  def test_baz
    @o.baz         # =>
  end

  def test_babar
    @o.babar       # =>
  end

  def test_fubar
    @o.fubar(10)   # =>
  end

  def test_difftype
    for x in @o.difftype
      x            # =>
    end
  end

end

