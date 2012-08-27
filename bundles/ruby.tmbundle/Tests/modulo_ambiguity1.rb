# purpose:
# exercise constructs with modulo
#
# modulo in math       data%2
# literals             %(a b), %W[1 2]
#
#
#

def test(v)
	p v
end

x, y = 42, 33


# -------------------------------------------
#
# Testarea for modulo
#
# -------------------------------------------

# value % value
test( 3%2 )
test( 3 % 2 )
test( 1234%(666) )
test( (1234)%666 )

# var % value
test( x%2 )
test( x%666 )
test( x%(42) )
test( x%-42-3 )
test( x%+42+3 )

# value % var
test( 666%x )
test( (42+4+2)%x )

# var % var
test( x % y )
test( x%y )

# -------------------------------------------
#
# Testarea for literals
#
# -------------------------------------------

# literal with nothing 
test( %(a b c) )
test( %(1 2 (3 4)) )
test( %{TM rocks} )

# literal with 'w' 
test( %W(1 2 3) )
test( %W[1 2 3] )
test( %W{1 2 3} )
test( %W<1 2 3> )

# literal with 'w'  (multiline)
test(%w(a
b))

# literal with 'q' 
test( %q(1 2 3) )
test( %Q(1 2 3) )

# literal with custom
test( %q"1 2 3" )
test( %q'1 2 3' )
test( %q#1 2 3# )
test( %?X.tainted? )
test( %q/1 2 3/ )
test( %q|1 2 3| )
test( %q\1 2 3\ )
