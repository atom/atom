
class X
  Y = Struct.new(:a)
  def foo(b); b ? Y.new(2) : 2 end
  def bar; raise "No good" end
  def baz; nil end
  def fubar(x); x ** 2.0 + 1 end
  def babar; [1,2] end
  A = 1
  A = 1
end


describe "xmpfilter's expectation expansion" do
  before do
    @o = X.new
  end

  it "should expand should == expectations" do
    @o.foo(true)   # =>
    @o.foo(true).a # =>
    @o.foo(false)  # =>
  end
  
  it "should expand should raise_error expectations" do
    @o.bar         # =>
  end

  it "should expand should be_nil expectations" do
    @o.baz         # =>
  end

  it "should expand correct expectations for complex values" do
    @o.babar       # =>
  end

  it "should expand should be_close expectations" do
    @o.fubar(10)   # =>
  end
end

describe "xmpfilter's automagic binding detection" do
  it "should expand should == expectations" do
    a = b = c = 1
    d = a
    d                                              # =>
  end
end
