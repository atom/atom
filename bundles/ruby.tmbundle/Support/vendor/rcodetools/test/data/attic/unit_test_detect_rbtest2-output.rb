=begin test_bar
assert_equal("BAR", bar("bar"))
=end
def bar(s)
  s.upcase
end
