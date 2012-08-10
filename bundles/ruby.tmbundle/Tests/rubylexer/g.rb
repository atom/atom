j=9;def i(n) [n ?"d" : "e" , n] end

p(i ?")
p(j ?"d" : "e")

def g(x=nil) x end
def gg(x=nil) g x end
p(gg :x)
p(g :y)
g=9
p(gg :z)
# g :w #error


