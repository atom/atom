require 'test/unit'
module MethodArgsScriptConfig
  DIR      = File.join(File.dirname(__FILE__))
  SCRIPT   = File.join(DIR, "..", "bin", "rct-meth-args")
  DATAFILE = File.join(DIR, "data/method_args.data.rb")
end

class TestMethodArgs < Test::Unit::TestCase
  # (find-sh "cd ..; method_args.rb -n test/method_args.data.rb")
  include MethodArgsScriptConfig
  @@result = `ruby '#{SCRIPT}' -n '#{DATAFILE}'`.split(/\n/)
  @@result.delete_if{ |line| line =~ /Digest/ and line !~ /method_in_Digest_Base/ }
  @@result.delete "zzzz OK"

  @@expected = <<XXX.split(/\n/)
method_args.data.rb:3:FixedArgsMethods.singleton (a1)
method_args.data.rb:4:FixedArgsMethods#initialize (arg)
method_args.data.rb:5:FixedArgsMethods#f (a1)
method_args.data.rb:6:FixedArgsMethods#b (a1, &block)
method_args.data.rb:7:FixedArgsMethods#defmethod (...)
method_args.data.rb:8:FixedArgsMethods#by_attr_accessor
method_args.data.rb:8:FixedArgsMethods#by_attr_accessor= (value)
method_args.data.rb:9:FixedArgsMethods#by_attr_false
method_args.data.rb:10:FixedArgsMethods#by_attr_true
method_args.data.rb:10:FixedArgsMethods#by_attr_true= (value)
method_args.data.rb:11:FixedArgsMethods#by_attr_reader_1
method_args.data.rb:11:FixedArgsMethods#by_attr_reader_2
method_args.data.rb:12:FixedArgsMethods#by_attr_writer= (value)
method_args.data.rb:13:FixedArgsMethods#private_meth (x)
method_args.data.rb:16:FixedArgsMethods.singleton_attr_accessor
method_args.data.rb:16:FixedArgsMethods.singleton_attr_accessor= (value)
method_args.data.rb:17:FixedArgsMethods.singleton_defmethod (...)
method_args.data.rb:22:VariableArgsMethods#s (a1, *splat)
method_args.data.rb:23:VariableArgsMethods#sb (a1, *splat, &block)
method_args.data.rb:24:VariableArgsMethods#d (a1, default = nil)
method_args.data.rb:25:VariableArgsMethods#ds (a1, default = nil, *splat)
method_args.data.rb:26:VariableArgsMethods#dsb (a1, default = nil, *splat, &block)
method_args.data.rb:27:VariableArgsMethods#db (a1, default = nil, &block)
method_args.data.rb:31:Fixnum#method_in_Fixnum (arg1, arg2)
method_args.data.rb:32:Fixnum.singleton_method_in_Fixnum (arg1, arg2)
method_args.data.rb:35:Bignum#method_in_Bignum (arg1, arg2)
method_args.data.rb:38:Float#method_in_Float (arg1, arg2)
method_args.data.rb:41:Symbol#method_in_Symbol (arg1, arg2)
method_args.data.rb:44:Binding#method_in_Binding (arg1, arg2)
method_args.data.rb:47:UnboundMethod#method_in_UnboundMethod (arg1, arg2)
method_args.data.rb:50:Method#method_in_Method (arg1, arg2)
method_args.data.rb:53:Proc#method_in_Proc (arg1, arg2)
method_args.data.rb:56:Continuation#method_in_Continuation (arg1, arg2)
method_args.data.rb:59:Thread#method_in_Thread (arg1, arg2)
method_args.data.rb:66:TrueClass#method_in_TrueClass (arg1, arg2)
method_args.data.rb:69:NilClass#method_in_NilClass (arg1, arg2)
method_args.data.rb:72:Struct#method_in_Struct (arg1, arg2)
Digest::Base#method_in_Digest_Base (...)
AnAbstractClass#method_in_AnAbstractClass (...)
method_args.data.rb:93:include AClass <= VariableArgsMethods
method_args.data.rb:94:extend AClass <- VariableArgsMethods
method_args.data.rb:97:class ASubClass < AClass
method_args.data.rb:100:class <Struct: a,b> < Struct
method_args.data.rb:101:class SubclassOfStructA < StructA
method_args.data.rb:102:SubclassOfStructA#method_in_b
method_args.data.rb:104:class <Struct: c> < Struct
method_args.data.rb:104:class StructSubclass < <Struct: c>
method_args.data.rb:105:StructSubclass#method_in_c
XXX

  # To avoid dependency of pwd.
  module StripDir
    def strip_dir!
      slice! %r!^.*/!
      self
    end
  end

  @@expected.each do |line|
    begin
      file_lineno_klass_meth, rest = line.split(/\s+/,2)
      if file_lineno_klass_meth =~ /:/
        file, lineno, klass_meth = file_lineno_klass_meth.split(/:/)
        klass_meth = rest if %w[class include extend].include? klass_meth
      else                        # filename/lineno is unknown
        klass_meth = file_lineno_klass_meth
      end

      test_method_name = "test_" + klass_meth
      define_method(test_method_name) do 
        actual = @@result.grep(/#{klass_meth}/)[0].extend(StripDir).strip_dir!
        assert_equal line, actual
      end
    rescue Exception
    end
  end
  
  def test_all_tests
    assert_equal @@expected.length, @@result.length, @@result.join("\n")
  end

  def test_without_n_option
    first_line = "FixedArgsMethods.singleton (a1)"
    command_output = `ruby '#{SCRIPT}'  '#{DATAFILE}'`
    assert_match(/\A#{Regexp.quote(first_line)}\n/, command_output)
  end
end


class TestTAGS < Test::Unit::TestCase
  include MethodArgsScriptConfig

  @@TAGS = `ruby '#{SCRIPT}' -t '#{DATAFILE}'`
  def test_filename
    # check whether full path is passed.
    assert_match %r!^\cl\n/.+method_args.data.rb,\d!, @@TAGS
  end

  def test_singleton_method
    # including line/byte test
    assert @@TAGS.include?("  def self.singleton(a1) end::FixedArgsMethods.singleton3,45")
  end

  def test_instance_method
    assert @@TAGS.include?("  def initialize(arg) end::FixedArgsMethods#initialize4,74")
  end

  def test_include
    assert_match(/^  include VariableArgsMethods::AClass/, @@TAGS)
  end

  def test_extend
    assert_match(/^  extend VariableArgsMethods::AClass/, @@TAGS)
  end

  def test_inheritance
    assert_match(/^class ASubClass < AClass::ASubClass/, @@TAGS)
  end
end
