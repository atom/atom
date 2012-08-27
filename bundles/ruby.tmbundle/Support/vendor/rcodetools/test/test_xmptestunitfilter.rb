
require 'test/unit'
$: << ".." << "../lib"
require "rcodetools/xmptestunitfilter"

class TestXMPTestUnitFilter < Test::Unit::TestCase
  include Rcodetools

  ANNOTATION_VAR_INFERENCE_INPUT = <<EOF
arr = []
X = Struct.new(:foo, :bar)
x = X.new("foo", "bar")
arr << x
arr                                                # \=>
arr.last                                           # \=>
EOF
  ANNOTATION_VAR_INFERENCE_OUTPUT = <<EOF
arr = []
X = Struct.new(:foo, :bar)
x = X.new(\"foo\", \"bar\")
arr << x
assert_equal([x], arr)
assert_kind_of(Array, arr)
assert_equal(\"[#<struct X foo=\\\"foo\\\", bar=\\\"bar\\\">]\", arr.inspect)
assert_equal(x, arr.last)
assert_kind_of(X, arr.last)
assert_equal(\"#<struct X foo=\\\"foo\\\", bar=\\\"bar\\\">\", arr.last.inspect)
EOF

  def test_annotation_var_inference
    xmp = XMPTestUnitFilter.new
    assert_equal(ANNOTATION_VAR_INFERENCE_OUTPUT, 
                 xmp.annotate(ANNOTATION_VAR_INFERENCE_INPUT).join(""))
  end

  def test_equality_assertions
    xmp = XMPTestUnitFilter.new
    assert_equal(["a = 1\n", "assert_equal(1, a)"], xmp.annotate("a = 1\na # \=>"))
    assert_equal(["a = {1,2}\n", "assert_equal({1=>2}, a)"], 
                 xmp.annotate("a = {1,2}\na # \=>"))
    assert_equal(["a = [1,2]\n", "assert_equal([1, 2], a)"], 
                 xmp.annotate("a = [1,2]\na # \=>"))
    assert_equal(["a = 'foo'\n", "assert_equal(\"foo\", a)"], 
                 xmp.annotate("a = 'foo'\na # \=>"))
    assert_equal(["a = 1.0\n", "assert_in_delta(1.0, a, 0.0001)"], 
                 xmp.annotate("a = 1.0\na # \=>"))
  end

  def test_raise_assertion
    code = <<EOF
class NoGood < Exception; end
raise NoGood                                       # \=>
EOF
    xmp = XMPTestUnitFilter.new
    assert_equal(["class NoGood < Exception; end\n", 
                 "assert_raise(NoGood){raise NoGood}\n"], xmp.annotate(code))
  end

  def test_assert_nil
    xmp = XMPTestUnitFilter.new
    assert_equal(["a = nil\n", "assert_nil(a)"], xmp.annotate("a = nil\na # \=>"))
  end

  def test_poetry_mode
    code = <<EOF
a = 1
a # \=>
a = 1.0
a # \=>
raise "foo" # \=>
a = nil
a # \=>
EOF
    output = <<EOF
a = 1
assert_equal 1, a
a = 1.0
assert_in_delta 1.0, a, 0.0001
assert_raise(RuntimeError){raise "foo"}
a = nil
assert_nil a
EOF
    xmp = XMPTestUnitFilter.new(:use_parentheses => false)
    assert_equal(output, xmp.annotate(code).join)
  end
end
