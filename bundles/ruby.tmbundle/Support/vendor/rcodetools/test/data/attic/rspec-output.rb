
class X
  Y = Struct.new(:a)
  def foo(b); b ? Y.new(2) : 2 end
  def bar; raise "No good" end
  def baz; nil end
  def fubar(x); x ** 2.0 + 1 end
  def babar; [1,2] end
  A = 1
  A = 1 # !> already initialized constant A
end


describe "xmpfilter's expectation expansion" do
  before do
    @o = X.new
  end

  it "should expand should == expectations" do
    (@o.foo(true)).should be_a_kind_of(X::Y)
    (@o.foo(true).inspect).should == ("#<struct X::Y a=2>")
    (@o.foo(true).a).should == (2)
    (@o.foo(false)).should == (2)
  end
  
  it "should expand should raise_error expectations" do
    lambda{@o.bar}.should raise_error(RuntimeError)
  end

  it "should expand should be_nil expectations" do
    (@o.baz).should be_nil
  end

  it "should expand correct expectations for complex values" do
    (@o.babar).should == ([1, 2])
  end

  it "should expand should be_close expectations" do
    (@o.fubar(10)).should be_close(101.0, 0.0001)
  end
end

describe "xmpfilter's automagic binding detection" do
  it "should expand should == expectations" do
    a = b = c = 1
    d = a
    (d).should == (a)
    (d).should == (b)
    (d).should == (c)
    (d).should == (1)
  end
end
