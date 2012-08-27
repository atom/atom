require 'rcodetools/xmpfilter'

module Rcodetools

FLOAT_TOLERANCE = 0.0001
class XMPTestUnitFilter < XMPFilter
  def initialize(opts = {})
    super
    @output_stdout = false
    mod = @parentheses ? :WithParentheses : :Poetry
    extend self.class.const_get(mod) unless opts[:_no_extend_module]
  end

  private
  def annotated_line(line, expression, runtime_data, idx)
    indent =  /^\s*/.match(line)[0]
    assertions(expression.strip, runtime_data, idx).map{|x| indent + x}.join("\n")
  end

  def prepare_line(expr, idx)
    basic_eval = prepare_line_annotation(expr, idx)
    %|begin; #{basic_eval}; rescue Exception; $stderr.puts("#{MARKER}[#{idx}] ~> " + $!.class.to_s); end|
  end

  def assertions(expression, runtime_data, index)
    exceptions = runtime_data.exceptions
    ret = []

    unless (vars = runtime_data.bindings[index]).empty?
      vars.each{|var| ret << equal_assertion(var, expression) }
    end
    if !(wanted = runtime_data.results[index]).empty? || !exceptions[index]
      case (wanted[0][1] rescue 1)
      when "nil"
        ret.concat nil_assertion(expression)
      else
        case wanted.size
        when 1
          ret.concat _value_assertions(wanted[0], expression)
        else
          # discard values from multiple runs
          ret.concat(["#xmpfilter: WARNING!! extra values ignored"] + 
                     _value_assertions(wanted[0], expression))
        end
      end
    else
      ret.concat raise_assertion(expression, exceptions, index)
    end

    ret
  end

  OTHER = Class.new
  def _value_assertions(klass_value_txt_pair, expression)
    klass_txt, value_txt = klass_value_txt_pair
    value = eval(value_txt) || OTHER.new
    # special cases
    value = nil if value_txt.strip == "nil"
    value = false if value_txt.strip == "false"
    value_assertions klass_txt, value_txt, value, expression
  rescue Exception
    return object_assertions(klass_txt, value_txt, expression)
  end

  def raise_assertion(expression, exceptions, index)
    ["assert_raise(#{exceptions[index][0]}){#{expression}}"]
  end

  module WithParentheses
    def nil_assertion(expression)
      ["assert_nil(#{expression})"]
    end

    def value_assertions(klass_txt, value_txt, value, expression)
      case value
      when Float
        ["assert_in_delta(#{value.inspect}, #{expression}, #{FLOAT_TOLERANCE})"]
      when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
        ["assert_equal(#{value_txt}, #{expression})"]
      else
        object_assertions(klass_txt, value_txt, expression)
      end
    end

    def object_assertions(klass_txt, value_txt, expression)
      [ "assert_kind_of(#{klass_txt}, #{expression})",
        "assert_equal(#{value_txt.inspect}, #{expression}.inspect)" ]
    end

    def equal_assertion(expected, actual)
      "assert_equal(#{expected}, #{actual})"
    end
  end

  module Poetry
    def nil_assertion(expression)
      ["assert_nil #{expression}"]
    end

    def value_assertions(klass_txt, value_txt, value, expression)
      case value
      when Float
        ["assert_in_delta #{value.inspect}, #{expression}, #{FLOAT_TOLERANCE}"]
      when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
        ["assert_equal #{value_txt}, #{expression}"]
      else
        object_assertions klass_txt, value_txt, expression
      end
    end

    def object_assertions(klass_txt, value_txt, expression)
      [ "assert_kind_of #{klass_txt}, #{expression} ",
        "assert_equal #{value_txt.inspect}, #{expression}.inspect" ] 
    end

    def equal_assertion(expected, actual)
      "assert_equal #{expected}, #{actual}"
    end
  end
end

class XMPRSpecFilter < XMPTestUnitFilter
  def initialize(x={})
    super(x.merge(:_no_extend_module => true))
    load_rspec
    specver = (Spec::VERSION::STRING rescue "1.0.0")
    api_module = specver >= "0.8.0" ? NewAPI : OldAPI
    @interpreter_info.execute_method = :execute_script
    mod = @parentheses ? :WithParentheses : :Poetry
    extend api_module.const_get(mod) 
    extend api_module
  end

  private
  def load_rspec
    begin
      require 'spec/version'
    rescue LoadError
      require 'rubygems'
      begin
        require 'spec/version'
      rescue LoadError # if rspec isn't available, use most recent conventions
      end
    end
  end

#  alias :execute :execute_script

  def interpreter_command
    [@interpreter] + @libs.map{|x| "-r#{x}"}
  end

  module NewAPI
    def raise_assertion(expression, exceptions, index)
      ["lambda{#{expression}}.should raise_error(#{exceptions[index][0]})"]
    end

    module WithParentheses
      def nil_assertion(expression)
        ["(#{expression}).should be_nil"]
      end

      def value_assertions(klass_txt, value_txt, value, expression)
        case value
        when Float
          ["(#{expression}).should be_close(#{value.inspect}, #{FLOAT_TOLERANCE})"]
        when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
          ["(#{expression}).should == (#{value_txt})"]
        else
          object_assertions klass_txt, value_txt, expression
        end
      end

      def object_assertions(klass_txt, value_txt, expression)
        [ "(#{expression}).should be_a_kind_of(#{klass_txt})",
          "(#{expression}.inspect).should == (#{value_txt.inspect})" ]
      end

      def equal_assertion(expected, actual)
        "(#{actual}).should == (#{expected})"
      end
    end

    module Poetry
      def nil_assertion(expression)
        ["#{expression}.should be_nil"]
      end

      def value_assertions(klass_txt, value_txt, value, expression)
        case value
        when Float
          ["#{expression}.should be_close(#{value.inspect}, #{FLOAT_TOLERANCE})"]
        when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
          ["#{expression}.should == #{value_txt}"]
        else
          object_assertions klass_txt, value_txt, expression
        end
      end

      def object_assertions(klass_txt, value_txt, expression)
        [ "#{expression}.should be_a_kind_of(#{klass_txt})",
          "#{expression}.inspect.should == #{value_txt.inspect}" ]
      end

      def equal_assertion(expected, actual)
        "#{actual}.should == #{expected}"
      end
    end
  end

  module OldAPI
    # old rspec, use deprecated syntax
    def raise_assertion(expression, exceptions, index)
      ["lambda{#{expression}}.should_raise_error(#{exceptions[index][0]})"]
    end

    module WithParentheses
      def nil_assertion(expression)
        ["(#{expression}).should_be_nil"]
      end

      def value_assertions(klass_txt, value_txt, value, expression)
        case value
        when Float
          ["(#{expression}).should_be_close(#{value.inspect}, #{FLOAT_TOLERANCE})"]
        when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
          ["(#{expression}).should_equal(#{value_txt})"]
        else
          object_assertions klass_txt, value_txt, expression
        end
      end

      def object_assertions(klass_txt, value_txt, expression)
        [ "(#{expression}).should_be_a_kind_of(#{klass_txt})",
          "(#{expression}.inspect).should_equal(#{value_txt.inspect})" ]
      end

      def equal_assertion(expected, actual)
        "(#{actual}).should_equal(#{expected})"
      end
    end

    module Poetry
      def nil_assertion(expression)
        ["#{expression}.should_be_nil"]
      end

      def value_assertions(klass_txt, value_txt, value, expression)
        case value
        when Float
          ["#{expression}.should_be_close #{value.inspect}, #{FLOAT_TOLERANCE}"]
        when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
          ["#{expression}.should_equal #{value_txt}"]
        else
          object_assertions klass_txt, value_txt, expression
        end
      end

      def object_assertions(klass_txt, value_txt, expression)
        [ "#{expression}.should_be_a_kind_of #{klass_txt}",
          "#{expression}.inspect.should_equal #{value_txt.inspect}" ]
      end

      def equal_assertion(expected, actual)
        "#{actual}.should_equal #{expected}"
      end
    end
  end


end

class XMPExpectationsFilter < XMPTestUnitFilter
  def initialize(x={})
    super(x.merge(:_no_extend_module => true))
    @warnings = false
  end
  
  def expectation(expected, actual)
    <<EOE
expect #{expected} do
    #{actual}
  end
EOE
  end
  alias :equal_assertion :expectation

  def raise_assertion(expression, exceptions, index)
    [ expectation(exceptions[index][0], expression) ]
  end
  
  def nil_assertion(expression)
    [ expectation("nil", expression) ]
  end
  
  def value_assertions(klass_txt, value_txt, value, expression)
    case value
    when Float
      min = "%.4f" % [value - FLOAT_TOLERANCE]
      max = "%.4f" % [value + FLOAT_TOLERANCE]
      [ expectation("#{min}..#{max}", expression) ]
    when Numeric, String, Hash, Array, Regexp, TrueClass, FalseClass, Symbol, NilClass
      [ expectation(value_txt, expression) ]
    else
      object_assertions klass_txt, value_txt, expression 
    end
  end
  
  def object_assertions(klass_txt, value_txt, expression)
    [ expectation(klass_txt, expression),
      expectation(value_txt.inspect, "#{expression}.inspect") ]
  end
end                             # /XMPExpectationsFilter
end                             # /Rcodetools
