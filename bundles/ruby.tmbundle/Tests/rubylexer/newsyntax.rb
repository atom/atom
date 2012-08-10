
x, (*), z = [:x, :y, :z]
p x
p z

x, (*y), z = [:x, :y, :z]
p x
p y
p z

p($/ = ' '; Array( "i'm in your house" ))

class Foou
 public
 def [] x=-100,&y=nil; p x; 100 end
end
p Foou.new.[]?9      #value
p Foou.new.[] ?9     #value
