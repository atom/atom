$: << ".." << "../lib"
require 'rcodetools/completion'
require 'test/unit'

class TestXMPCompletionFilter < Test::Unit::TestCase
  include Rcodetools
  def doit(code, lineno, column=nil, options={})
    xmp = XMPCompletionFilter.new options
    xmp.candidates(code, lineno, column).sort
  end

  def test_complete_method__simple
    assert_equal(["length"], doit('"a".lengt', 1))
    assert_equal(["length"], doit('`echo a`.lengt', 1))
  end

  def test_complete_method__in_arg
    assert_equal(["length"], doit('print("a".lengt)', 1, 15))
    assert_equal(["length"], doit("print('a'.lengt)", 1, 15))
    assert_equal(["length"], doit("((a, b = 1 + 'a'.lengt))", 1, 22))
  end

  def test_complete_method__in_method
    assert_equal(["length"], doit(<<EOC, 2))
  def hoge
    "a".lengt
  end
  hoge
EOC
  end

  def test_complete_method__in_not_passing_method
    assert_raises(XMPCompletionFilter::NoCandidates) do
      doit(<<EOC, 2)
  def hoge
    "a".lengt
  end
EOC
    end
  end

  def test_complete_singleton_method
    assert_equal(["aaaaa", "aaaab"], doit(<<EOC, 6))
  a = 'a'
  def a.aaaaa
  end
  def a.aaaab
  end
  a.aa
EOC
  end

  def test_complete_global_variable
    assert_equal(["$hoge"], doit(<<EOC, 2))
  $hoge = 100
  $ho
EOC
  end

  def test_complete_global_variable__list
    gvars = doit(<<EOC, 3)
  $foo = 3
  $hoge = 100
  $
EOC
    assert gvars.include?("$foo")
    assert gvars.include?("$hoge")
  end

  def test_complete_global_variable__with_class
    assert_equal(["open"], doit(<<EOC, 2))
  $hoge = File
  $hoge.op
EOC
  end


  def test_complete_instance_variable
    assert_equal(["@hoge"], doit(<<EOC, 2))
  @hoge = 100
  @ho
EOC
  end

  def test_complete_class_variable_module
    assert_equal(["@@hoge"], doit(<<EOC, 3))
  module X
    @@hoge = 100
    @@ho
  end
EOC
  end

  def test_complete_class_variable__in_class
    assert_equal(["@@hoge"], doit(<<EOC, 3))
  class X
    @@hoge = 100
    @@ho
  end
EOC
  end

  def test_complete_class_variable__toplevel
    assert_equal(["@@hoge"], doit(<<EOC, 2))
  @@hoge = 100
  @@ho
EOC
  end

  def test_complete_class_variable__in_method
    assert_equal(["@@hoge"], doit(<<EOC, 4))
  class Foo
    def foo
      @@hoge = 100
      @@ho
    end
  end
  Foo.new.foo
EOC
  end

  def test_complete_class_variable__list
    assert_equal(%w[@@foo @@hoge], doit(<<EOC, 3))
  @@hoge = 100
  @@foo = 2
  @@
EOC
  end


  def test_complete_constant__nested
    assert_equal(["Stat"], doit('File::Sta',1))
  end

  def test_complete_class_method
    assert_equal(["popen"], doit('File::pop',1))
    assert_equal(["popen"], doit('::File::pop',1))

    assert_equal(["popen"], doit('File.pop',1))
    assert_equal(["popen"], doit('::File.pop',1))

    assert_equal(["new"], doit('::File::Stat.ne',1))
    assert_equal(["new"], doit('File::Stat.ne',1))

  end


  def test_complete_constant__in_class
    assert_equal(["Fixclass", "Fixnum"], doit(<<EOC, 3))
  class Fixclass
    class Bar
      Fix
    end
  end
EOC
  end


  def test_complete_toplevel_constant
    assert_equal(["Fixnum"], doit(<<EOC,3))
  class Foo
    class Fixnum
      ::Fixn
    end
  end
EOC

    assert_equal(["Fixnum"], doit(<<EOC,3))
  class Foo
    class Fixnum
      ::Foo::Fixn
    end
  end
EOC

    assert_equal(["Bar"], doit(<<EOC,5))
  class Foo
    class Bar
    end
  end
  ::Foo::B
EOC
  end

  def test_bare_word__local_variable
    assert_equal(["aaaaaxx"], doit(<<EOC,2))
  aaaaaxx = 1
  aaaa
EOC
  end

  def test_bare_word__method
    assert_equal(["trace_var"], doit("trace",1))
  end

  def test_bare_word__constant
    assert_equal(["Fixnum"], doit("Fixn",1))
  end
    
  def test_bare_word__method_in_class
    assert_equal(["attr_accessor"], doit(<<EOC,2))
  class X
    attr_acc
  end
EOC
  end

  def test_bare_word__public_method
    assert_equal(["hoge"], doit(<<EOC,4))
  class X
    def hoge() end
    def boke
      hog
    end
    new.boke
  end
EOC
  end

  def test_bare_word__private_method
    assert_equal(["hoge"], doit(<<EOC,5))
  class X
    def hoge() end
    private :hoge
    def boke
      hog
    end
    new.boke
  end
EOC
  end

  def test_complete_symbol
    assert_equal([":vccaex"], doit(<<EOC,2))
a = :vccaex
:vcca
EOC
    
  end

  #### tricky testcases
  def test_two_pass
    assert_equal(["inspect"], doit(<<EOC,2))
  [1, "a"].each do |x|
    x.inspec
  end
EOC
  end

  def test_string
    assert_equal(["inspect"], doit('"()".inspe',1))
    assert_equal(["inspect"], doit('`echo ()`.inspe',1))
  end

  def test_not_last_line
    assert_equal(["inspect"], doit(<<EOC,1))
  "".inspe
  1
EOC
  end

  def test_column
    assert_equal(["length"], doit('print("a".lengt + "b".size)', 1, 15))
  end

  def test_method_chain__String
    assert_equal(["length"], doit('"a".upcase.capitalize.leng', 1))
  end

  def test_method_chain__Fixnum
    assert_equal(["length"], doit('1.to_s.upcase.leng', 1))
  end

  def test_multi_line__do
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[].each_with_ind do |x|
end
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[].each_with_ind()do |x|
end
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[].each_with_ind do |x,y| end
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[1].each_with_index do |x,y| [].each do end end
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[].each_with_ind ; do-do
EOC
  end

  def test_multi_line__braces
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[].each_with_ind { |x|
}
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[].each_with_ind(){ |x|
}
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[].each_with_ind {|x,y| }
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 16))
[1].each_with_in {|x,y| [].each { }}
EOC
    assert_equal(["each_with_index"], doit(<<EOC, 1, 20))
{ [1].each_with_inde {|x,y| [].each { }},1}

EOC
  end

  def test_multi_line__brackets
    assert_equal(["each_with_index"], doit(<<EOC, 1, 20))
[ [1].each_with_inde {|x,y| [].each { }},
1]
EOC
  end

  def test_multi_line__parentheses
    assert_equal(["each_with_index"], doit(<<EOC, 1, 23))
foo( [1].each_with_inde {|x,y| [].each { }},
     1)
EOC
=begin FIXME
     assert_equal(["each_with_index"], doit(<<EOC, 2, 23))
 foo( 1,
      [1].each_with_inde {|x,y| [].each { }})
EOC
=end
  end

  def test_multi_line__control_structures__if
    assert_equal(["length"], doit(<<EOC, 1))
if "a".leng
end
EOC
    assert_equal(["length"], doit(<<EOC, 1, 8))
"a".leng if true
EOC
    assert_equal(["length"], doit(<<EOC, 1, 8))
"a".leng ; if true
  1
end
EOC
    assert_equal(["length"], doit(<<EOC, 1, 8))
"a".leng ;if true
  1
end
EOC
  end

  def test_multi_line__control_structures__if_in_string
    assert_equal(["length"], doit(<<EOC, 1))
"if a".leng
EOC
    assert_equal(["length"], doit(<<EOC, 1))
'if a'.leng
EOC
    assert_equal(["length"], doit(<<EOC, 1))
`if a`.leng
EOC
  end
  
  def test_multi_line__control_structures__other_keywords
    assert_equal(["length"], doit(<<EOC, 1))
unless "a".leng
end
EOC
    assert_equal(["length"], doit(<<EOC, 1))
while "a".leng
end
EOC
    assert_equal(["length"], doit(<<EOC, 1))
until "a".leng
end
EOC
    assert_equal(["split"], doit(<<EOC, 1))
for a in "a".spli
end
EOC
  end

  def test_phrase
    assert_equal(["uniq", "uniq!"], doit('Array.new(3).uni',1))
    assert_equal(["uniq", "uniq!"], doit('Array.new(3).to_a.uni',1))
    assert_equal(["uniq", "uniq!"], doit('Array.new(3).map{|x| x.to_i}.uni',1))
    assert_equal(["uniq", "uniq!"], doit('[][0,(1+1)].uni',1))
 end

  def test_percent__String
    assert_equal(["length"], doit('%!foo!.leng',1))
    assert_equal(["length"], doit('%q!foo!.leng',1))
    assert_equal(["length"], doit('%Q!foo!.leng',1))
    assert_equal(["length"], doit('%x!foo!.leng',1))

    assert_equal(["length"], doit('%{foo}.leng',1))
    assert_equal(["length"], doit('%q{foo}.leng',1))
    assert_equal(["length"], doit('%q!(!.leng',1))
    assert_equal(["length"], doit('%Q!(!.leng',1))
    assert_equal(["length"], doit('%x!(!.leng',1))
    assert_equal(["length"], doit('%x{(}.leng',1))

    assert_equal(["length"], doit('%{f(o)o}.leng',1))
    assert_equal(["length"], doit('%{f{o}o}.leng',1))
    assert_equal(["length"], doit('(%{f{o}o}+%!}x!).leng',1))
  end

  def test_percent__Array
    assert_equal(["length"], doit('%w!foo!.leng',1))
    assert_equal(["length"], doit('%W!foo!.leng',1))

    assert_equal(["length"], doit('%w{foo}.leng',1))
    assert_equal(["length"], doit('%W{foo}.leng',1))
    assert_equal(["length"], doit('%w!(!.leng',1))
    assert_equal(["length"], doit('%W!(!.leng',1))
    assert_equal(["length"], doit('%w{(}.leng',1))

    assert_equal(["length"], doit('%w{f(o)o}.leng',1))
    assert_equal(["length"], doit('%w{f{o}o}.leng',1))
    assert_equal(["length"], doit('(%W{f{o}o}+%w!}x!).leng',1))
  end

  def test_percent__Regexp
    assert_equal(["kcode"], doit('%r!foo!.kcod',1))
    assert_equal(["kcode"], doit('%r{foo}.kcod',1))
    assert_equal(["kcode"], doit('%r!(!.kcod',1))
    assert_equal(["kcode"], doit('%r{(}.kcod',1))
    assert_equal(["kcode"], doit('%r{f(o)o}.kcod',1))
  end

  def test_percent__Symbol
    assert_equal(["id2name"], doit('%s!foo!.id2nam',1))
    assert_equal(["id2name"], doit('%s{foo}.id2nam',1))
    assert_equal(["id2name"], doit('%s!(!.id2nam',1))
    assert_equal(["id2name"], doit('%s{(}.id2nam',1))
    assert_equal(["id2name"], doit('%s{f(o)o}.id2nam',1))
  end

  def test_complete_method__with_NoMethodError
    assert_equal(["module_function"], doit(<<EOC, 3, nil, :ignore_NoMethodError=>true))
  module X
    xx                          # normally NoMethodError
    module_funct
  end
EOC
  end

  # drawback of ignore_NoMethodError
  def test_with_or_without_ignore_NoMethodError
    code = <<EOC
a=[1]
x = a[1][0] rescue "aaa"
x.lengt
EOC
    assert_equal(["length"], doit(code, 3))
    assert_raises(XMPCompletionFilter::NoCandidates) do
      doit(code, 3, nil, :ignore_NoMethodError=>true)
    end
  end

  def test__syntax_error
    assert_raise(ProcessParticularLine::NewCodeError) do
      doit(<<EOC, 5)
end
module X
  def x
  end
  module_function
end
EOC
    end
  end

  def test__runtime_error
    assert_raise(ProcessParticularLine::NewCodeError) do
      doit(<<EOC, 5)
__undefined_method__
module X
  def x
  end
  module_function
end
EOC
    end
  end


  # This is a caveat!! You should use dabbrev for this case.
  def XXtest_oneline
    assert_equal(["aaa"], doit('aaa=1; aa', 1))
  end

################################################################  

  def get_class(code, lineno, column=nil, options={})
    xmp = XMPCompletionFilter.new options
    klass, = xmp.runtime_data_with_class(code, lineno, column).sort
    klass
  end

  def test_class__Class
    assert_equal("File", get_class("File::n", 1))
    assert_equal("File", get_class("File.n", 1))
    assert_equal("File::Stat", get_class("File::Stat::n", 1))
    assert_equal("File::Stat", get_class("File::Stat.n", 1))

    assert_equal("FileTest", get_class("FileTest.exis", 1))
    assert_equal("FileTest", get_class("FileTest::exis", 1))
  end

  def test_class__NotClass
    assert_equal("Fixnum", get_class("1.ch", 1))
    assert_equal("String", get_class("'a'.siz", 1))
  end
end


class TestXMPCompletionVerboseFilter < Test::Unit::TestCase
  include Rcodetools
  def doit(code, lineno, column=nil, options={})
    xmp = XMPCompletionVerboseFilter.new options
    xmp.candidates(code, lineno, column).sort
  end

  def test_complete_global_variable
    assert_equal(["$hoge"], doit(<<EOC, 2))
  $hoge = 100
  $ho
EOC
  end

  def test_complete_instance_variable
    assert_equal(["@hoge"], doit(<<EOC, 2))
  @hoge = 100
  @ho
EOC
  end

  def test_complete_list_instance_variable
    assert_equal(%w[@bar @baz @foo @hoge], doit(<<EOC, 5))
  @foo = 1
  @bar = 2
  @baz = 3
  @hoge = 100
  @
EOC
  end

  def test_complete_class_variable_module
    assert_equal(["@@hoge"], doit(<<EOC, 3))
  module X
    @@hoge = 100
    @@ho
  end
EOC
  end

  def test_complete_constant__nested
    assert_equal(["Stat"], doit('File::Sta',1))
  end

  def test_complete_class_method
    assert_equal(["popen\0IO.popen"], doit('File::pop',1))
    assert_equal(["popen\0IO.popen"], doit('::File::pop',1))

    assert_equal(["popen\0IO.popen"], doit('File.pop',1))
    assert_equal(["popen\0IO.popen"], doit('::File.pop',1))

    assert_equal(["new\0File::Stat.new"], doit('::File::Stat.ne', 1))
    assert_equal(["new\0File::Stat.new"], doit('File::Stat.ne',1))

  end

  def test_complete_constant__in_class
    assert_equal(["Fixclass", "Fixnum"], doit(<<EOC, 3))
  class Fixclass
    class Bar
      Fix
    end
  end
EOC
  end


  def test_complete_toplevel_constant
    assert_equal(["Fixnum"], doit(<<EOC,3))
  class Foo
    class Fixnum
      ::Fixn
    end
  end
EOC

    assert_equal(["Fixnum"], doit(<<EOC,3))
  class Foo
    class Fixnum
      ::Foo::Fixn
    end
  end
EOC

    assert_equal(["Bar"], doit(<<EOC,5))
  class Foo
    class Bar
    end
  end
  ::Foo::B
EOC
  end

  def test_complete_symbol
    assert_equal([":vccaex"], doit(<<EOC,2))
a = :vccaex
:vcca
EOC
    
  end

  def test_method_chain__String
    assert_equal(["length\0String#length"], doit('"a".upcase.capitalize.leng', 1))
  end

  def test_bare_word__local_variable
    assert_equal(["aaaaaxx"], doit(<<EOC,2))
  aaaaaxx = 1
  aaaa
EOC
  end

  def test_bare_word__method
    assert_equal(["trace_var\0Kernel#trace_var"], doit("trace",1))
  end

  def test_bare_word__constant
    assert_equal(["Fixnum"], doit("Fixn",1))
  end
    
  def test_bare_word__method_in_class
    assert_equal(["attr_accessor\0Module#attr_accessor"], doit(<<EOC,2))
  class X
    attr_acc
  end
EOC
  end

  def test_bare_word__public_method
    assert_equal(["hoge\0X#hoge"], doit(<<EOC,4))
  class X
    def hoge() end
    def boke
      hog
    end
    new.boke
  end
EOC
  end

  def test_bare_word__private_method
    assert_equal(["hoge\0X#hoge"], doit(<<EOC,5))
  class X
    def hoge() end
    private :hoge
    def boke
      hog
    end
    new.boke
  end
EOC
  end

end
