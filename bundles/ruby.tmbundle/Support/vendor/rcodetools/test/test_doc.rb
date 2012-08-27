$: << ".." << "../lib"
require 'rcodetools/doc'
require 'test/unit'

class TestXMPDocFilter < Test::Unit::TestCase
  include Rcodetools
  def doit(code, lineno, column=nil, options={})
    xmp = XMPDocFilter.new options
    xmp.doc(code, lineno, column)
  end

  def test_instance_method__Array
    assert_equal("Array#length", doit("[].length", 1))
  end

  def test_instance_method__Fixnum
    assert_equal("Fixnum#to_s", doit("1.to_s", 1))
  end

  def test_instance_method__Enumerable
    assert_equal("Enumerable#each_with_index", doit("[].each_with_index", 1))
  end

  def test_instance_method__String
    assert_equal("String#length", doit("'a'.length", 1))
  end

  def test_class_method__IO_popen
    assert_equal("IO.popen", doit("IO::popen", 1))
    assert_equal("IO.popen", doit("IO.popen", 1))
  end

  def test_class_method__File_popen
    assert_equal("IO.popen", doit("File::popen", 1))
    assert_equal("IO.popen", doit("File.popen", 1))

    assert_equal("IO.popen", doit(<<EOC,2))
$hoge = File
$hoge.popen
EOC
  end

  # not File::Stat.methods(false).include? 'new'
  def test_class_method__File_Stat_new
    assert_equal("File::Stat.new", doit("File::Stat.new", 1))
    assert_equal("File::Stat.new", doit("File::Stat::new", 1))

    assert_equal("File::Stat.new", doit("::File::Stat.new", 1))
    assert_equal("File::Stat.new", doit("::File::Stat::new", 1))
  end

  # IO.methods(false).include? 'new'
  def test_class_method__IO_new
    assert_equal("IO.new", doit("IO.new", 1))
    assert_equal("IO.new", doit("IO::new", 1))

    assert_equal("IO.new", doit("::IO.new", 1))
    assert_equal("IO.new", doit("::IO::new", 1))
  end


  def test_constant__File
    assert_equal("File", doit("File", 1))
    assert_equal("File", doit("::File", 1))
  end

  def test_constant__File_Stat
    assert_equal("File::Stat", doit("File::Stat", 1))
    assert_equal("File::Stat", doit("::File::Stat", 1))
  end

  def test_instance_method__File_Stat
    assert_equal("File::Stat#atime", doit(<<EOC,2))
stat = File::Stat.new "#{__FILE__}"
stat.atime
EOC
    assert_equal("File::Stat#atime", doit(<<EOC,2))
stat = ::File::Stat.new "#{__FILE__}"
stat.atime
EOC
  end

  def test_instance_method__Hoge_File_Stat_1
    assert_equal("Hoge::File::Stat#atime", doit(<<EOC,11))
module Hoge
  module File
    class Stat
      def initialize(file)
      end
      def atime
      end
    end
  end
  stat = File::Stat.new "#{__FILE__}"
  stat.atime
end
EOC
  end

  def test_instance_method__Hoge_File_Stat_2
    assert_equal("File::Stat#atime", doit(<<EOC,11))
module Hoge
  module File
    class Stat
      def initialize(file)
      end
      def atime
      end
    end
  end
  stat = ::File::Stat.new "#{__FILE__}"
  stat.atime
end
EOC
  end

  def test_bare_word__Kernel
    assert_equal("Kernel#print", doit("print", 1))
  end

  def test_bare_word__Module
    assert_equal("Kernel#print", doit(<<EOC, 2))
module Foo
  print
end
EOC
  end

  def test_bare_word__class
    assert_equal("Kernel#print", doit(<<EOC, 2))
class Foo
  print
end
EOC
  end


  def test_bare_word__Module_attr
    assert_equal("Module#attr", doit(<<EOC, 2))
module Foo
  attr
end
EOC
  end

  def test_bare_word__Class_superclass
    assert_equal("Class#superclass", doit(<<EOC, 2))
class Foo
  superclass
end
EOC
  end

  def test_bare_word__Class_object_id
    assert_equal("Object#object_id", doit(<<EOC, 2))
class Foo
  object_id
end
EOC
  end


  def test_bare_word__self
    assert_equal("Foo#foo", doit(<<EOC, 3))
class Foo
  def initialize
    foo
  end
  attr :foo
  new
end
EOC
  end

  def test_column
    assert_equal("Array#length", doit("[].length + 10", 1, 9))
    assert_equal("Array#length", doit("[].length + 10", 1, 5))
  end

  def test_method_chain__String
    assert_equal("String#length", doit('"a".upcase.capitalize.length', 1))
    assert_equal("String#capitalize", doit('"a".upcase.capitalize.length', 1, 21))
  end

  def test_method_chain__Fixnum
    assert_equal("String#length", doit('1.to_s.upcase.length', 1))
    assert_equal("String#upcase", doit('1.to_s.upcase.length', 1, 13))
  end

  def test_multi_line__do
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[].each_with_index do |x|
end
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[].each_with_index()do |x|
end
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[].each_with_index do |x,y| end
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[1].each_with_index do |x,y| [].each do end end
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[].each_with_index ; do-do
EOC
  end

  def test_multi_line__braces
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[].each_with_index { |x|
}
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[].each_with_index(){ |x|
}
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[].each_with_index {|x,y| }
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 16))
[1].each_with_index {|x,y| [].each { }}
EOC
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 20))
{ [1].each_with_index {|x,y| [].each { }},1}

EOC
  end

  def test_multi_line__brackets
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 20))
[ [1].each_with_index {|x,y| [].each { }},
1]
EOC
  end

  def test_multi_line__parentheses
    assert_equal("Enumerable#each_with_index", doit(<<EOC, 1, 23))
foo( [1].each_with_index {|x,y| [].each { }},
     1)
EOC
=begin FIXME
     assert_equal("Enumerable#each_with_index", doit(<<EOC, 2, 23))
 foo( 1,
      [1].each_with_index {|x,y| [].each { }})
EOC
=end
  end

  def test_multi_line__control_structures__if
    assert_equal("String#length", doit(<<EOC, 1))
if "a".length
end
EOC
    assert_equal("String#length", doit(<<EOC, 1, 8))
"a".length if true
EOC
    assert_equal("String#length", doit(<<EOC, 1, 8))
"a".length ; if true
  1
end
EOC
    assert_equal("String#length", doit(<<EOC, 1, 8))
"a".length ;if true
  1
end
EOC
  end

  def test_multi_line__control_structures__if_in_string
    assert_equal("String#length", doit(<<EOC, 1))
"if a".length
EOC
    assert_equal("String#length", doit(<<EOC, 1))
'if a'.length
EOC
    assert_equal("String#length", doit(<<EOC, 1))
`if a`.length
EOC
  end
  
  def test_multi_line__control_structures__other_keywords
    assert_equal("String#length", doit(<<EOC, 1))
unless "a".length
end
EOC
    assert_equal("String#length", doit(<<EOC, 1))
while "a".length
end
EOC
    assert_equal("String#length", doit(<<EOC, 1))
until "a".length
end
EOC
    assert_equal("String#split", doit(<<EOC, 1))
for a in "a".split
end
EOC
  end

  def test_operator
    #  +@ -@ is not supported
    %w[ |  ^  &  <=>  ==  ===  =~  >   >=  <   <=   <<  >>
        +  -  *  /    %   **   ~
    ].each do |op|
      ancestors_re = Fixnum.ancestors.map{|x|x.to_s}.join('|')
      assert_match(/^#{ancestors_re}##{Regexp.quote(op)}$/, doit("1 #{op} 2",1,2))
    end
  end

  def test_aref_aset__Array
    assert_equal("Array#[]", doit("[0][ 0 ]",1,4))
    assert_equal("Array#[]=", doit("[0][ 0 ]=10",1,4))
    assert_equal("Array#[]", doit("[0][0]",1,4))
    assert_equal("Array#[]=", doit("[0][0]=10",1,4))
  end

  def test_aref_aset__Object
    assert_equal("Array#[]", doit("Array.new(3)[ 0 ]",1,13))
    assert_equal("Array#[]=", doit("Array.new(3)[ 0 ]=10",1,13))
    assert_equal("Array#[]", doit("Array.new(3)[0]",1,13))
    assert_equal("Array#[]=", doit("Array.new(3)[0]=10",1,13))
  end

  def test_aref_aset__Fixnum
    assert_equal("Fixnum#[]", doit("0[ 0 ]",1,2))
    assert_equal("Fixnum#[]", doit("0[0]",1,2))
  end

  def test_aref_aset__String
    assert_equal("String#[]", doit("'a' + '[0]'[ 0 ]",1,12))
    assert_equal("String#[]", doit("'[0]'[ 0 ]",1,6))
    assert_equal("String#[]=", doit("'0'[ 0 ]=10",1,4))
    assert_equal("String#[]", doit("'[0]'[0]",1,6))
    assert_equal("String#[]=", doit("'0'[0]=10",1,4))
  end

  def test_phrase
    assert_equal("Array#uniq", doit('Array.new(3).uniq',1))
    assert_equal("Array#uniq", doit('Array.new(3).to_a.uniq',1))
    assert_equal("Array#uniq", doit('Array.new(3).map{|x| x.to_i}.uniq',1))
    assert_equal("Array#uniq", doit('[][0,(1+1)].uniq',1))
 end

  def test_percent__String
    assert_equal("String#length", doit('%!foo!.length',1))
    assert_equal("String#length", doit('%q!foo!.length',1))
    assert_equal("String#length", doit('%Q!foo!.length',1))
    assert_equal("String#length", doit('%x!foo!.length',1))

    assert_equal("String#length", doit('%{foo}.length',1))
    assert_equal("String#length", doit('%q{foo}.length',1))
    assert_equal("String#length", doit('%q!(!.length',1))
    assert_equal("String#length", doit('%Q!(!.length',1))
    assert_equal("String#length", doit('%x!(!.length',1))
    assert_equal("String#length", doit('%x{(}.length',1))

    assert_equal("String#length", doit('%{f(o)o}.length',1))
    assert_equal("String#length", doit('%{f{o}o}.length',1))
    assert_equal("String#length", doit('(%{f{o}o}+%!}x!).length',1))
  end

  def test_percent__Array
    assert_equal("Array#length", doit('%w!foo!.length',1))
    assert_equal("Array#length", doit('%W!foo!.length',1))

    assert_equal("Array#length", doit('%w{foo}.length',1))
    assert_equal("Array#length", doit('%W{foo}.length',1))
    assert_equal("Array#length", doit('%w!(!.length',1))
    assert_equal("Array#length", doit('%W!(!.length',1))
    assert_equal("Array#length", doit('%w{(}.length',1))

    assert_equal("Array#length", doit('%w{f(o)o}.length',1))
    assert_equal("Array#length", doit('%w{f{o}o}.length',1))
    assert_equal("Array#length", doit('(%W{f{o}o}+%w!}x!).length',1))
  end

  def test_percent__Regexp
    assert_equal("Regexp#kcode", doit('%r!foo!.kcode',1))
    assert_equal("Regexp#kcode", doit('%r{foo}.kcode',1))
    assert_equal("Regexp#kcode", doit('%r!(!.kcode',1))
    assert_equal("Regexp#kcode", doit('%r[(].kcode',1))
    assert_equal("Regexp#kcode", doit('%r<f(o)o>.kcode',1))
  end

  def test_percent__Symbol
    assert_equal("Symbol#id2name", doit('%s!foo!.id2name',1))
    assert_equal("Symbol#id2name", doit('%s{foo}.id2name',1))
    assert_equal("Symbol#id2name", doit('%s!(!.id2name',1))
    assert_equal("Symbol#id2name", doit('%s{(}.id2name',1))
    assert_equal("Symbol#id2name", doit('%s(f(o)o).id2name',1))
  end

  def test_bare_word__with_NoMethodError
    assert_equal("Module#module_function", doit(<<EOC, 3, nil, :ignore_NoMethodError=>true))
  module X
    xx                          # normally NoMethodError
    module_function
  end
EOC
  end

  def test__syntax_error
    assert_raise(ProcessParticularLine::NewCodeError) do
      doit(<<EOC, 5, nil)
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
      doit(<<EOC, 5, nil)
__undefined_method__
module X
  def x
  end
  module_function
end
EOC
    end
  end
end

class TestXMPRiFilter < Test::Unit::TestCase
  include Rcodetools
  def doit(code, lineno, column=nil, options={})
    xmp = XMPRiFilter.new options
    xmp.doc(code, lineno, column)
  end

  def test_class_method__IO_popen
    assert_equal("ri 'IO::popen'", doit("IO::popen", 1))
    assert_equal("ri 'IO::popen'", doit("IO.popen", 1))
  end

  def test_instance_method__Array
    assert_equal("ri 'Array#length'", doit("[].length", 1))
  end
end
