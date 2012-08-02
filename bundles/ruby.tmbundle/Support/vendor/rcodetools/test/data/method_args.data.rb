# method_args.data.rb
class FixedArgsMethods
  def self.singleton(a1) end
  def initialize(arg) end
  def f(a1) end
  def b(a1,&block) end
  define_method(:defmethod) {|a1|}
  attr_accessor :by_attr_accessor
  attr :by_attr_false
  attr :by_attr_true, true
  attr_reader :by_attr_reader_1, :by_attr_reader_2
  attr_writer :by_attr_writer
  def private_meth(x) end
  private :private_meth
  class << self
    attr_accessor :singleton_attr_accessor
    define_method(:singleton_defmethod){|a2|}
  end
end

module VariableArgsMethods
  def s(a1,*splat) end
  def sb(a1,*splat, &block) end
  def d(a1,default=nil) end
  def ds(a1,default=nil,*splat) end
  def dsb(a1,default=nil,*splat,&block) end
  def db(a1,default=nil,&block) end
end

class Fixnum
  def method_in_Fixnum(arg1, arg2) end
  def self.singleton_method_in_Fixnum(arg1, arg2) end
end
class Bignum
  def method_in_Bignum(arg1, arg2) end
end
class Float
  def method_in_Float(arg1, arg2) end
end
class Symbol
  def method_in_Symbol(arg1, arg2) end
end
class Binding
  def method_in_Binding(arg1, arg2) end
end
class UnboundMethod
  def method_in_UnboundMethod(arg1, arg2) end
end
class Method
  def method_in_Method(arg1, arg2) end
end
class Proc
  def method_in_Proc(arg1, arg2) end
end
class Continuation
  def method_in_Continuation(arg1, arg2) end
end
class Thread
  def method_in_Thread(arg1, arg2) end
end
# FIXME mysterious
# class FalseClass
#   def method_in_FalseClass(arg1, arg2) end
# end
class TrueClass
  def method_in_TrueClass(arg1, arg2) end
end
class NilClass
  def method_in_NilClass(arg1, arg2) end
end
class Struct
  def method_in_Struct(arg1, arg2) end
end

require 'digest'
class Digest::Base
  def method_in_Digest_Base(arg1, arg2) end
end

class AnAbstractClass
  $__method_args_off = true
  def self.allocate
    raise NotImplementedError, "#{self} is an abstract class."
  end
  $__method_args_off = false

  def method_in_AnAbstractClass(arg1, arg2)
  end

end

class AClass
  include VariableArgsMethods
  extend VariableArgsMethods
end

class ASubClass < AClass
end

StructA = Struct.new :a, :b
class SubclassOfStructA < StructA
  attr :method_in_b
end
class StructSubclass < Struct.new(:c)
  attr :method_in_c
end
