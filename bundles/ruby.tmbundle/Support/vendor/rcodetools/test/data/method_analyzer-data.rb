
class A
  def A.foo
    1
  end

  def a
    1+1
  end
end
class B < A
  def initialize
  end
  attr_accessor :bb
  
  def b
    "a".length
  end
end
tm = Time.now
[tm.year, tm.month, tm.day] << 0
a = A.new
a.a
b = B.new
b.a
b.b
[b.a,b.b]
z = b.a + b.b
A.foo
B.foo
b.bb=1
b.bb

