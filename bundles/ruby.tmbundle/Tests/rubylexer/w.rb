p %r{\/$}
p %r~<!include:([\/\w\.\-]+)>~m

p [].push *[1,2,3]
p /\n/

$a=1
@b=2
@@c=3
p(/\#$a \#@b \#@@c \#{$a+@b+@@c}/)


class Foo
attr :foo,true
end
f=Foo.new
p f.foo
p f.foo=9
p f.foo =19
p f.foo= 29
p f.foo = 39
p f.foo
