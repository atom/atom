require 'rcodetools/completion'
# Call Ri for any editors!!
#  by rubikitch <rubikitch@ruby-lang.org>
module Rcodetools

class XMPDocFilter < XMPFilter
  include ProcessParticularLine

  def initialize(opts = {})
    super
    @filename = opts[:filename]
    extend UseMethodAnalyzer if opts[:use_method_analyzer]
  end

  def self.run(code, opts)
    new(opts).doc(code, opts[:lineno], opts[:column])
  end

  def prepare_line(expr, column)
    set_expr_and_postfix!(expr, column){|c| 
      withop_re = /^.{#{c-1}}[#{OPERATOR_CHARS}]+/
      if expr =~ withop_re
        withop_re
      else
        /^.{#{c}}[\w#{OPERATOR_CHARS}]*/
      end
    }
    recv = expr

    # When expr already knows receiver and method,
    return(__prepare_line :recv => expr.eval_string, :meth => expr.meth) if expr.eval_string

    case expr
    when /^(?:::)?([A-Z].*)(?:::|\.)(.*)$/    # nested constants / class methods
      __prepare_line :klass => $1, :meth_or_constant => $2
    when /^(?:::)?[A-Z]/               # normal constants
      __prepare_line :klass => expr
    when /\.([^.]*)$/             # method call
      __prepare_line :recv => Regexp.last_match.pre_match, :meth => $1
    when /^(.+)(\[\]=?)$/                   # [], []=
      __prepare_line :recv => $1, :meth => $2
    when /[#{OPERATOR_CHARS}]+$/                   # operator
      __prepare_line :recv => Regexp.last_match.pre_match, :meth => $&
    else                        # bare words
      __prepare_line :recv => "self", :meth => expr
    end
  end

  def __prepare_line(x)
    v = "#{VAR}"
    result = "#{VAR}_result"
    klass = "#{VAR}_klass"
    flag = "#{VAR}_flag"
    which_methods = "#{VAR}_methods"
    ancestor_class = "#{VAR}_ancestor_class"
    idx = 1
    recv = x[:recv] || x[:klass] || raise(ArgumentError, "need :recv or :klass")
    meth = x[:meth_or_constant] || x[:meth]
    debugprint "recv=#{recv}", "meth=#{meth}"
    if meth
      # imported from fastri/MagicHelp
      code = <<-EOC
#{v} = (#{recv})
$stderr.print("#{MARKER}[#{idx}] => " + #{v}.class.to_s  + " ")

if Module === #{v} and '#{meth}' =~ /^[A-Z]/ and #{v}.const_defined?('#{meth}')
  #{result} = #{v}.to_s + "::#{meth}"
else
  #{__magic_help_code result, v, meth.dump}
end

$stderr.puts(#{result})
exit
      EOC
    else
      code = <<-EOC
#{v} = (#{recv})
$stderr.print("#{MARKER}[#{idx}] => " + #{v}.class.to_s  + " ")
$stderr.puts(#{v}.to_s)
exit
      EOC
    end
    oneline_ize(code)
  end

  # overridable by module
  def _doc(code, lineno, column)
  end

  def doc(code, lineno, column=nil)
    _doc(code, lineno, column) or runtime_data(code, lineno, column).to_s
  end

  module UseMethodAnalyzer
    METHOD_ANALYSIS = "method_analysis"
    def have_method_analysis
      File.file? METHOD_ANALYSIS
    end

    def find_method_analysis
      here = Dir.pwd
      oldpwd = here
      begin
        while ! have_method_analysis
          Dir.chdir("..")
          if Dir.pwd == here
            return nil          # not found
          end
          here = Dir.pwd
        end
      ensure
        Dir.chdir oldpwd
      end
      yield(File.join(here, METHOD_ANALYSIS))
    end

    def _doc(code, lineno, column=nil)
      find_method_analysis do |ma_file|
        methods = open(ma_file, "rb"){ |f| Marshal.load(f)}
        line = File.readlines(@filename)[lineno-1]
        current_method = line[ /^.{#{column}}\w*/][ /\w+[\?!]?$/ ].sub(/:+/,'')
        filename = @filename  # FIXME
        begin 
          methods[filename][lineno].grep(Regexp.new(Regexp.quote(current_method)))[0]
        rescue NoMethodError
          raise "doc/method_analyzer:cannot find #{current_method}"
        end

      end
    end
  end

end

# ReFe is so-called `Japanese Ri'.
class XMPReFeFilter < XMPDocFilter
  def doc(code, lineno, column=nil)
    "refe '#{super}'"
  end
end

class XMPRiFilter < XMPDocFilter
  def doc(code, lineno, column=nil)
    "ri '#{super.sub(/\./, '::')}'"
  end
end

class XMPRiEmacsFilter < XMPDocFilter
  def doc(code, lineno, column=nil)
    begin 
      %!(rct-find-tag-or-ri "#{super}")!
    rescue Exception => err
      return %Q[(error "#{err.message}")]
    end
  end
end

class XMPRiVimFilter < XMPDocFilter
  def doc(code, lineno, column=nil)
    begin
      %{call RCT_find_tag_or_ri("#{super}")}
    rescue Exception => err
      return %Q[echo #{err.message.inspect}]
    end
  end
end

end
