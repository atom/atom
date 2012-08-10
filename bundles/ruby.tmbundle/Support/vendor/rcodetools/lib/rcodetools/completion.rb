# Nearly 100% accurate completion for any editors!!
#  by rubikitch <rubikitch@ruby-lang.org>

require 'rcodetools/xmpfilter'
require 'enumerator'

module Rcodetools

# Common routines for XMPCompletionFilter/XMPDocFilter
module ProcessParticularLine
  def fill_literal!(expr)
    [ "\"", "'", "`" ].each do |q|
      expr.gsub!(/#{q}(.+)#{q}/){ '"' + "x"*$1.length + '"' }
    end
    expr.gsub!(/(%([wWqQxrs])?(\W))(.+?)\3/){
      percent = $2 == 'x' ? '%'+$3 : $1 # avoid executing shell command
      percent + "x"*$4.length + $3
    }
    [ %w[( )], %w[{ }], %w![ ]!, %w[< >] ].each do |b,e|
      rb, re = [b,e].map{ |x| Regexp.quote(x)}
      expr.gsub!(/(%([wWqQxrs])?(#{rb}))(.+)#{re}/){
        percent = $2 == 'x' ? '%'+$3 : $1 # avoid executing shell command
        percent + "x"*$4.length + e
      }
    end
  end

  module ExpressionExtension
    attr_accessor :eval_string
    attr_accessor :meth
  end
  OPERATOR_CHARS = '\|^&<>=~\+\-\*\/%\['
  def set_expr_and_postfix!(expr, column, &regexp)
    expr.extend ExpressionExtension

    @postfix = ""
    expr_orig = expr.clone
    column ||= expr.length
    last_char = expr[column-1]
    expr.replace expr[ regexp[column] ]
    debugprint "expr_orig=#{expr_orig}", "expr(sliced)=#{expr}"
    right_stripped = Regexp.last_match.post_match
    _handle_do_end right_stripped
    aref_or_aset = aref_or_aset? right_stripped, last_char
    debugprint "aref_or_aset=#{aref_or_aset.inspect}"
    set_last_word! expr, aref_or_aset
    fill_literal! expr_orig
    _handle_brackets expr_orig, expr
    expr << aref_or_aset if aref_or_aset
    _handle_keywords expr_orig, column
    debugprint "expr(processed)=#{expr}"
    expr
  end

  def _handle_do_end(right_stripped)
    right_stripped << "\n"
    n_do = right_stripped.scan(/[\s\)]do\s/).length
    n_end = right_stripped.scan(/\bend\b/).length
    @postfix = ";begin" * (n_do - n_end)
  end

  def _handle_brackets(expr_orig, expr)
    [ %w[{ }], %w[( )], %w![ ]! ].each do |left, right|
      n_left  = expr_orig.count(left)  - expr.count(left)
      n_right = expr_orig.count(right) - expr.count(right)
      n = n_left - n_right
      @postfix << ";#{left}" * n if n >= 0
    end
  end

  def _handle_keywords(expr_orig, column)
    %w[if unless while until for].each do |keyw|
      pos = expr_orig.index(/\b#{keyw}\b/)
      @postfix << ";begin" if pos and pos < column # if * xxx

      pos = expr_orig.index(/;\s*#{keyw}\b/)
      @postfix << ";begin" if pos and column < pos # * ; if xxx
    end
  end

  def aref_or_aset?(right_stripped, last_char)
    if last_char == ?[
      case right_stripped
      when /\]\s*=/ then "[]="
      when /\]/     then "[]"
      end
    end
  end

  def set_last_word!(expr, aref_or_aset=nil)
    debugprint "expr(before set_last_word)=#{expr}"
    if aref_or_aset
      opchars = "" 
    else
      opchars = expr.slice!(/\s*[#{OPERATOR_CHARS}]+$/)
      debugprint "expr(strip opchars)=#{expr}"
    end
    
    expr.replace(if expr =~ /[\"\'\`]$/      # String operations
                   "''"
                 else
                   fill_literal! expr
                   phrase = current_phrase(expr)
                   if aref_or_aset
                     expr.eval_string = expr[0..-2]
                     expr.meth = aref_or_aset
                   elsif phrase.match( /^(.+)\.(.*)$/ )
                     expr.eval_string, expr.meth = $1, $2
                   elsif opchars != ''
                     expr
                   end
                   debugprint "expr.eval_string=#{expr.eval_string}", "expr.meth=#{expr.meth}"
                   phrase
                 end << (opchars || '')) # ` font-lock hack
    debugprint "expr(after set_last_word)=#{expr}"
  end

  def current_phrase(expr)
    paren_level = 0
    start = 0
    (expr.length-1).downto(0) do |i|
      c = expr[i,1]
      if c =~ /[\)\}\]]/
        paren_level += 1
        next
      end
      if paren_level > 0
        next if c =~ /[, ]/
      else
        break (start = i+1) if c =~ /[ ,\(\{\[]/
      end
      if c =~ /[\(\{\[]/
        paren_level -= 1
        break (start = i+1) if paren_level < 0
      end
    end
    expr[start..-1]
  end

  def add_BEGIN
    <<XXX
BEGIN {
class Object
  def method_missing(meth, *args, &block)
    # ignore NoMethodError
  end
end
}
XXX
  end

  class RuntimeDataError < RuntimeError; end
  class NewCodeError < Exception; end
  def runtime_data_with_class(code, lineno, column=nil)
    newcode = code.to_a.enum_with_index.map{|line, i|
      i+1==lineno ? prepare_line(line.chomp, column) : line
    }.join
    newcode << add_BEGIN if @ignore_NoMethodError
    debugprint "newcode", newcode.gsub(/;/, "\n"), "-"*80
    stdout, stderr = execute(newcode)
    output = stderr.readlines
    debugprint "stderr", output, "-"*80
    output = output.reject{|x| /^-:[0-9]+: warning/.match(x)}
    runtime_data = extract_data(output)
    if exception = /^-:[0-9]+:.*/m.match(output.join)
      raise NewCodeError, exception[0].chomp
    end
    begin
      dat = runtime_data.results[1][0]
      debugprint "dat = #{dat.inspect}"
      [dat[0], dat[1..-1].to_s]
    rescue
      raise RuntimeDataError, runtime_data.inspect
    end
  end

  def runtime_data(code, lineno, column=nil)
    runtime_data_with_class(code, lineno, column)[1]
  end

  def __magic_help_code(result, v, meth)
    code = <<-EOC
  #{result} = #{v}.method(#{meth}).inspect.match( %r[\\A#<(?:Unbound)?Method: (.*?)>\\Z] )[1].sub(/\\A.*?\\((.*?)\\)(.*)\\Z/){ "\#{$1}\#{$2}" }.sub(/#<Class:(.*?)>#/) { "\#{$1}." }
  #{result} = #{v}.to_s + ".new" if #{result} == 'Class#new' and #{v}.private_method_defined?(:initialize)
  #{result} = "Object#" + #{meth} if #{result} =~ /^Kernel#/ and Kernel.instance_methods(false).map{|x| x.to_s}.include? #{meth}
  #{result}
EOC
  end

end

# Nearly 100% accurate completion for any editors!!
#  by rubikitch <rubikitch@ruby-lang.org>
class XMPCompletionFilter < XMPFilter
  include ProcessParticularLine

  class << self
    attr_accessor :candidates_with_description_flag
  end
  @candidates_with_description_flag = false

  # String completion begins with this.
  attr :prefix

  def self.run(code, opts)
    new(opts).completion_code(code, opts[:lineno], opts[:column])
  end

  def magic_help_code(recv, meth)
    oneline_ize __magic_help_code("#{VAR}_result", recv, meth)
  end

  def methods_map_code(recv)
    # delimiter is \0
    m = "#{VAR}_m"
    mhc = magic_help_code((recv), m)
    %Q[map{|%s| "\#{%s}\\0" + %s}] % [m, m, mhc]
  end

  def split_method_info(minfo)
    minfo.split(/\0/,2)
  end

  def prepare_line(expr, column)
    set_expr_and_postfix!(expr, column){|c| /^.{#{c}}/ }
    @prefix = expr
    case expr
    when /^\$\w*$/              # global variable
      __prepare_line 'nil', 'global_variables', '%n'
    when /^@@\w*$/              # class variable
      __prepare_line 'nil', 'Module === self ? class_variables : self.class.class_variables', '%n'
    when /^@\w*$/               # instance variable
      __prepare_line 'nil', 'instance_variables', '%n'
    when /^([A-Z].*)::([^.]*)$/    # nested constants / class methods
      @prefix = $2
      __prepare_line $1, "#$1.constants | #$1.methods(true)",
      %Q[#$1.constants + #$1.methods(true).#{methods_map_code($1)}]
    when /^[A-Z]\w*$/           # normal constants
      __prepare_line 'nil', 'Module.constants', '%n'
    when /^(.*::.+)\.(.*)$/       # toplevel class methods
      @prefix = $2
      __prepare_line $1, "#$1.methods",
      %Q[%n.#{methods_map_code($1)}]
    when /^(::.+)::(.*)$/       # toplevel nested constants
      @prefix = $2
      __prepare_line $1, "#$1.constants | #$1.methods",
      %Q[#$1.constants + #$1.methods.#{methods_map_code($1)}]
    when /^::(.*)/              # toplevel constant
      @prefix = $1
      __prepare_line 'nil', 'Object.constants', '%n'
    when /^(:[^:.]*)$/          # symbol
      __prepare_line 'nil', 'Symbol.all_symbols.map{|s| ":" + s.id2name}', '%n'
    when /\.([^.]*)$/           # method call
      @prefix = $1
      recv = Regexp.last_match.pre_match
      __prepare_line recv, "(#{recv}).methods(true)",
      %Q[%n.#{methods_map_code(recv)}]
    else                        # bare words
      __prepare_line 'self', "methods | private_methods | local_variables | self.class.constants",
      %Q[(methods | private_methods).#{methods_map_code('self')} + local_variables | self.class.constants]
    end
  end

  def __prepare_line(recv, all_completion_expr, all_completion_expr_verbose)
    if self.class.candidates_with_description_flag
      ___prepare_line(recv, all_completion_expr_verbose.gsub(/%n/, '('+all_completion_expr+')'))
    else
      ___prepare_line(recv, all_completion_expr) 
    end

  end

  def ___prepare_line(recv, all_completion_expr)
    v = "#{VAR}"
    rcv = "#{VAR}_recv"
    idx = 1
    oneline_ize(<<EOC)
#{rcv} = (#{recv})
#{v} = (#{all_completion_expr}).map{|x| x.to_s}.grep(/^#{Regexp.quote(@prefix)}/)
#{rcv} = Module === #{rcv} ? #{rcv} : #{rcv}.class
$stderr.puts("#{MARKER}[#{idx}] => " + #{rcv}.to_s  + " " + #{v}.join(" ")) || #{v}
exit
EOC
  end

  def candidates_with_class(code, lineno, column=nil)
    klass, methods = runtime_data_with_class(code, lineno, column) rescue ["", ""]
    raise NoCandidates, "No candidates." if methods.nil? or methods.empty?
    [klass, methods.split(/ /).sort]
  end

  # Array of completion candidates.
  class NoCandidates < RuntimeError;  end
  def candidates(code, lineno, column=nil)
    candidates_with_class(code, lineno, column)[1]
  end

  # Completion code for editors.
  def completion_code(code, lineno, column=nil)
    candidates(code, lineno, column).join("\n") rescue "\n"
  end
end

# for debugging XMPCompletionEmacsFilter
class XMPCompletionVerboseFilter < XMPCompletionFilter
  @candidates_with_description_flag = true
end

class XMPCompletionClassInfoFilter < XMPCompletionFilter
  @candidates_with_description_flag = true

  def completion_code(code, lineno, column=nil)
    candidates(code, lineno, column).join("\n").tr("\0", "\t")
  rescue NoCandidates
    ""
  end
end

class XMPCompletionEmacsFilter < XMPCompletionFilter
  @candidates_with_description_flag = true

  def completion_code(code, lineno, column=nil)
    elisp = "(progn\n"
    table = "(setq rct-method-completion-table '("
    alist = "(setq alist '("
    begin
      candidates(code, lineno, column).sort.each do |minfo|
        meth, description = split_method_info(minfo)
        table << format('("%s") ', meth)
        alist << format('("%s\\t[%s]") ', meth, description)
      end
      table << "))\n"
      alist << "))\n"
    rescue Exception => err
      return error_code(err)
    end
    elisp << table << alist
    elisp << %Q[(setq pattern "#{prefix}")\n]
    elisp << %Q[(try-completion pattern rct-method-completion-table nil)\n]
    elisp << ")"                # /progn
  end

  def error_code(err)
    case err
    when NoCandidates
      %Q[(error "#{err.message}")]
    else
      %Q[(error "#{err.message}\n#{err.backtrace.join("\n")}")]
    end

  end
end

class XMPCompletionEmacsIciclesFilter < XMPCompletionEmacsFilter
  @candidates_with_description_flag = true

  def completion_code(code, lineno, column=nil)
    elisp = "(progn\n"
    table = "(setq rct-method-completion-table '("
    help_alist = "(setq alist '("
    
    begin
      klass, cands = candidates_with_class(code, lineno, column)
      cands.sort.each do |minfo|
        meth, description = split_method_info(minfo)
        table << format('("%s\\t[%s]") ', meth, description)
        help_alist << format('("%s" . "%s")', meth, description)
      end
      table << "))\n"
      help_alist << "))\n"
    rescue Exception => err
      return error_code(err)
    end
    elisp << table << help_alist
    elisp << %Q[(setq pattern "#{prefix}")\n]
    elisp << %Q[(setq klass "#{klass}")\n]
    elisp << ")"                # /progn
  end
end

class XMPCompletionEmacsAnythingFilter < XMPCompletionEmacsFilter
  @candidates_with_description_flag = true

  def completion_code(code, lineno, column=nil)
    elisp = "(progn\n"
    table = "(setq rct-method-completion-table `("
    
    begin
      klass, cands = candidates_with_class(code, lineno, column)
      cands.sort.each do |minfo|
        meth, description = split_method_info(minfo)
        table << format('("%s\\t[%s]" . ,(propertize "%s" \'desc "%s")) ',
          meth, description, meth, description)
      end
      table << "))\n"
    rescue Exception => err
      return error_code(err)
    end
    elisp << table
    elisp << %Q[(setq pattern "#{prefix}")\n]
    elisp << %Q[(setq klass "#{klass}")\n]
    elisp << ")"                # /progn
  end
end

end
