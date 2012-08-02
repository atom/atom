# purpose:
# exercise constructs with division
#
# division itself      84 / 2
# regexp               /pattern/
#
#
#

def test(*obj)
	p(*obj)
end
a, b = 4, 2

# -------------------------------------------
#
# Testarea for division
#
# -------------------------------------------

# singleline numbers
test(84 / 2)

# singleline symbols
test(a / b)

# singleline symbols
test(a / b / 3)


test(Float(42) / Float(5))

# multiline with symbols
=begin # invalid
test(a 
/ b)
=end

# multiline with symbols
test(a / 
b)


# -------------------------------------------
#
# Testarea for regexp
#
# -------------------------------------------

# singleline
test( // )
test( /abc/ )
test( /a\/bc/ )
test [/^F../]
p 'Foobar'[/^F../]
p '42' =~ /42/
test(nil && /\\/ =~ '\\')
test(nil || /\\/ =~ '\\')
test(nil and /\\/ =~ '\\')
test(nil or /\\/ =~ '\\')
test(/a/x)
test(/x/.match('abx').to_s)
test((/x/).match('abx').to_s)
test(/a/,/b/,/c/)
test(/a/x,/b/x,/c/m)


# multiline
test( /
pattern
/x    )


# multiline
test( 
/r
eg
e/x
)

# multiline
test( 
/1/,/2/,/3/
)

# regexp after keyword
res = case 'test';when /t..t/:1;else 0;end
test(res)