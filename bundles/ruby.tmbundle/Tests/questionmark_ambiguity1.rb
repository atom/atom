# purpose:
# exercise constructs with questionmark
#
# numeric letters      ?x
# ternary operator     condition ? case1 : case2
#
#
#

def test(v)
	puts "#{v.inspect} => #{v.chr}"
end
def z(v)
	v
end



# -------------------------------------------
#
# Testarea for numeric letters
#
# -------------------------------------------

# begin of line
test(
?x) 

# normal letters
test( ?a )
test( ?A )
test( ?0 )

# misc symbols
test( ?* )
test( ?**2 )
test( ?: )
test( ?) )
test( ?( )
test( ?' )   # im a comment, not a string
test( ?" )   # im a comment, not a string
test( ?/ )   # im a comment, not a regexp

# symbol '.'
test( ?..succ )
p ?...?..succ     # im a .. range
p ?....?..succ    # im a ... range
#p ?.....?..succ    # invalid

# symbol '#'
test( ?# ); p 'im not a comment' 

# space ' '
#test( ?  )     # invalid

# tab '	'
#test( ?	 )     # invalid


# symbol '?'
test( ?? )    
test(??)

# symbol '\\'
test( ?\\ )

# escaped as hex
#test( ?\x )     # invalid
test( ?\x1 )
test( ?\x61 )
#test( ?\x612 )  # invalid
test( ?\X )   # valid.. but is not hex
#test( ?\X11 )   # invalid

# escaped as octal
test( ?\0 )
test( ?\07 )
test( ?\017 )
#test( ?\0173 )   # invalid
#test( ?\08 )     # invalid
#test( ?\09 )     # invalid
#test( ?\0a )     # invalid
test( ?\1 )
test( ?\7 )
test( ?\a )
test( ?\f )

# standard escapings
test( ?\n )  # newline
test( ?\b )  # backspace

# escaped misc letters/symbols
test( ?\8 )
test( ?\9 )
test( ?\_ )

# ctrl/meta escaped
test( ?\C-a )
test( ?\C-g )
test( ?\C-x )
test( ?\C-A )
test( ?\C-G )
test( ?\c )
test( ?\m )
#test( ?\c-a )   # invalid
#test( ?\C )     # invalid
#test( ?\M )     # invalid
test( ?\M-a )
test( ?\M-\C-a )
test( ?\C-\C-\M-a )
test( ?\C-\M-a )
test( ?\C-\M-\M-a )
test( ?\C-\M-\C-\M-a )

# misc tests
p 'abc'.include?(?z)



# -------------------------------------------
#
# Testarea for ternary operator
#
# -------------------------------------------
a, b, val = 42, 24, true
p(val ? 0 : 2)

p [
 val ? (a) : z(b)    ,
 val ? 'a' : 'b'
]




# -------------------------------------------
#
# Testarea for ternary operator and numeric letter
#
# -------------------------------------------
p [

# very ugly
true ???:??    ,
true ???:?:    ,
true ??::?:    ,
]



# -------------------------------------------
#
# Testarea for neiter ternary operator nor numeric letter
#
# -------------------------------------------

# not letters.. the questionmark is part of the methodname
p(42.tainted?, 42.frozen?)


