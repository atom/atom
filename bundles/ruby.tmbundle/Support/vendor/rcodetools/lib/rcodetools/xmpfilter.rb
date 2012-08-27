#!/usr/bin/env ruby
# Copyright (c) 2005-2008 Mauricio Fernandez <mfp@acm.org> http://eigenclass.org
#                         rubikitch <rubikitch@ruby-lang.org>
# Use and distribution subject to the terms of the Ruby license.

# This is needed regexps cannot match with invalid-encoding strings.
# xmpfilter is unaware of script encoding.
Encoding.default_external = "ASCII-8BIT" if RUBY_VERSION >= "1.9"

ENV['HOME'] ||= "#{ENV['HOMEDRIVE']}#{ENV['HOMEPATH']}"
require 'rcodetools/fork_config'
require 'rcodetools/compat'
require 'tmpdir'

module Rcodetools

class XMPFilter
  VERSION = "0.8.7"

  MARKER = "!XMP#{Time.new.to_i}_#{Process.pid}_#{rand(1000000)}!"
  XMP_RE = Regexp.new("^" + Regexp.escape(MARKER) + '\[([0-9]+)\] (=>|~>|==>) (.*)')
  VAR = "_xmp_#{Time.new.to_i}_#{Process.pid}_#{rand(1000000)}"
  WARNING_RE = /.*:([0-9]+): warning: (.*)/

  RuntimeData = Struct.new(:results, :exceptions, :bindings)

  INITIALIZE_OPTS = {:interpreter => "ruby", :options => [], :libs => [],
                     :include_paths => [], :warnings => true, 
                     :use_parentheses => true}

  def windows?
    /win|mingw/ =~ RUBY_PLATFORM && /darwin/ !~ RUBY_PLATFORM
  end

  Interpreter = Struct.new(:options, :execute_method, :accept_debug, :accept_include_paths, :chdir_proc)
  INTERPRETER_RUBY = Interpreter.new(["-w"],
    :execute_ruby, true, true, nil)
  INTERPRETER_RBTEST = Interpreter.new(["-S", "rbtest"],
    :execute_script, false, false, nil)
  INTERPRETER_FORK = Interpreter.new(["-S", "rct-fork-client"],
    :execute_tmpfile, false, true,
    lambda { Fork::chdir_fork_directory })
                                     
  def self.detect_rbtest(code, opts)
    opts[:use_rbtest] ||= (opts[:detect_rbtest] and code =~ /^=begin test./) ? true : false
  end

  # The processor (overridable)
  def self.run(code, opts)
    new(opts).annotate(code)
  end

  def initialize(opts = {})
    options = INITIALIZE_OPTS.merge opts
    @interpreter_info = INTERPRETER_RUBY
    @interpreter = options[:interpreter]
    @options = options[:options]
    @libs = options[:libs]
    @evals = options[:evals] || []
    @include_paths = options[:include_paths]
    @output_stdout = options[:output_stdout]
    @dump = options[:dump]
    @warnings = options[:warnings]
    @parentheses = options[:use_parentheses]
    @ignore_NoMethodError = options[:ignore_NoMethodError]
    test_script = options[:test_script]
    test_method = options[:test_method]
    filename = options[:filename]
    @execute_ruby_tmpfile = options[:execute_ruby_tmpfile]
    @postfix = ""
    @stdin_path = nil
    @width = options[:width]
    
    initialize_rct_fork if options[:detect_rct_fork]
    initialize_rbtest if options[:use_rbtest]
    initialize_for_test_script test_script, test_method, filename if test_script and !options[:use_rbtest]
  end

  def initialize_rct_fork
    if Fork::run?
      @interpreter_info = INTERPRETER_FORK
    end
  end

  def initialize_rbtest
    @interpreter_info = INTERPRETER_RBTEST
  end

  def initialize_for_test_script(test_script, test_method, filename)
    test_script.replace File.expand_path(test_script)
    filename.replace File.expand_path(filename)
    unless test_script == filename
      basedir = common_path(test_script, filename)
      relative_filename = filename[basedir.length+1 .. -1].sub(%r!^lib/!, '')
      @evals << %Q!$LOADED_FEATURES << #{relative_filename.dump}!
      @evals << safe_require_code('test/unit')
      @evals << %Q!load #{test_script.dump}!
    end
    test_method = get_test_method_from_lineno(test_script, test_method.to_i) if test_method =~ /^\d/
    @evals << %Q!Test::Unit::AutoRunner.run(false, nil, ["-n", #{test_method.dump}])! if test_method
  end

  def get_test_method_from_lineno(filename, lineno)
    lines = File.readlines(filename)
    (lineno-1).downto(0) do |i|
      if lines[i] =~ /^ *def *(test_[A-Za-z0-9?!_]+)$/
        return $1
      end
    end
    nil
  end

  def common_path(a, b)
    (a.split(File::Separator) & b.split(File::Separator)).join(File::Separator)
  end

  def add_markers(code, min_codeline_size = 50)
    maxlen = code.map{|x| x.size}.max
    maxlen = [min_codeline_size, maxlen + 2].max
    ret = ""
    code.each do |l|
      l = l.chomp.gsub(/ # (=>|!>).*/, "").gsub(/\s*$/, "")
      ret << (l + " " * (maxlen - l.size) + " # =>\n")
    end
    ret
  end

  SINGLE_LINE_RE = /^(?!(?:\s+|(?:\s*#.+)?)# ?=>)(.*) # ?=>.*/
  MULTI_LINE_RE = /^(.*)\n(( *)# ?=>.*(?:\n|\z))(?: *#    .*\n)*/
  def annotate(code)
    idx = 0
    code = code.gsub(/ # !>.*/, '')
    newcode = code.gsub(SINGLE_LINE_RE){ prepare_line($1, idx += 1) }
    newcode.gsub!(MULTI_LINE_RE){ prepare_line($1, idx += 1, true)}
    File.open(@dump, "w"){|f| f.puts newcode} if @dump
    execute(newcode) do |stdout, stderr|
      output = stderr.readlines
      runtime_data = extract_data(output)
      idx = 0
      annotated = code.gsub(SINGLE_LINE_RE) { |l|
        expr = $1
        if /^\s*#/ =~ l
          l 
        else
          annotated_line(l, expr, runtime_data, idx += 1)
        end
      }
      annotated.gsub!(/ # !>.*/, '')
      annotated.gsub!(/# (>>|~>)[^\n]*\n/m, "");
      annotated.gsub!(MULTI_LINE_RE) { |l|
        annotated_multi_line(l, $1, $3, runtime_data, idx += 1)
      }
      ret = final_decoration(annotated, output)
      if @output_stdout and (s = stdout.read) != ""
        ret << s.inject(""){|s,line| s + "# >> #{line}".chomp + "\n" }
      end
      ret
    end
  end

  def annotated_line(line, expression, runtime_data, idx)
    "#{expression} # => " + (runtime_data.results[idx].map{|x| x[1]} || []).join(", ")
  end
  
  def annotated_multi_line(line, expression, indent, runtime_data, idx)
    pretty = (runtime_data.results[idx].map{|x| x[1]} || []).join(", ")
    first, *rest = pretty.to_a
    rest.inject("#{expression}\n#{indent}# => #{first || "\n"}") {|s, l| s << "#{indent}#    " << l }
  end
  
  def prepare_line_annotation(expr, idx, multi_line=false)
    v = "#{VAR}"
    blocal = "__#{VAR}"
    blocal2 = "___#{VAR}"
    lastmatch = "____#{VAR}"
    if multi_line
      pp = safe_require_code "pp"
      result = "((begin; #{lastmatch} = $~; PP.pp(#{v}, '', #{@width-5}).gsub(/\\r?\\n/, 'PPPROTECT'); ensure; $~ = #{lastmatch} end))"
    else
      pp = ''
      result = "#{v}.inspect"
    end
    oneline_ize(<<-EOF).chomp
#{pp}
#{v} = (#{expr})
$stderr.puts("#{MARKER}[#{idx}] => " + #{v}.class.to_s + " " + #{result}) || begin
  $stderr.puts local_variables
  local_variables.each{|#{blocal}|
    #{blocal2} = eval(#{blocal})
    if #{v} == #{blocal2} && #{blocal} != %#{expr}.strip
      $stderr.puts("#{MARKER}[#{idx}] ==> " + #{blocal})
    elsif [#{blocal2}] == #{v}
      $stderr.puts("#{MARKER}[#{idx}] ==> [" + #{blocal} + "]")
    end
  }
  nil
rescue Exception
  nil
end || #{v}
    EOF

  end
  alias_method :prepare_line, :prepare_line_annotation

  def safe_require_code(lib)
    oldverbose = "$#{VAR}_old_verbose"
    "#{oldverbose} = $VERBOSE; $VERBOSE = false; require '#{lib}'; $VERBOSE = #{oldverbose}"
  end
  private :safe_require_code

  def execute_ruby(code)
    meth = (windows? or @execute_ruby_tmpfile) ? :execute_tmpfile : :execute_popen
    __send__ meth, code
  end

  def split_shbang(script)
    ary = script.each_line.to_a
    if ary[0] =~ /^#!/ and ary[1] =~ /^#.*coding/
      [ary[0..1], ary[2..-1]]
    elsif ary[0] =~ /^#!|^#.*coding/ 
      [[ary[0]], ary[1..-1]]
    else
      [[], ary]
    end
  end
  private :split_shbang

  def execute_tmpfile(code)
    ios = %w[_ stdin stdout stderr]
    stdin, stdout, stderr = (1..3).map do |i|
      fname = if $DEBUG
                "xmpfilter.tmpfile_#{ios[i]}.rb"
              else
                "xmpfilter.tmpfile_#{Process.pid}-#{i}.rb"
              end
      f = File.open(fname, "w+")
      f
    end
    # stdin.puts code
    # stdin.close
    shbang_magic_comment, rest = split_shbang(code)
    @stdin_path = File.expand_path stdin.path
    stdin.print shbang_magic_comment
    stdin.print <<-EOF.map{|l| l.strip}.join(";")
      $stdout.reopen('#{File.expand_path(stdout.path)}', 'w')
      $stderr.reopen('#{File.expand_path(stderr.path)}', 'w')
      $0 = '#{File.expand_path(stdin.path)}'
      ARGV.replace(#{@options.inspect})
      END { #{@evals.join(";")} }
    EOF
    stdin.print ";#{rest}"
    
    debugprint "execute command = #{(interpreter_command << stdin.path).join ' '}"
    stdin.close
    oldpwd = Dir.pwd
    @interpreter_info.chdir_proc and @interpreter_info.chdir_proc.call
    system(*(interpreter_command << stdin.path))
    Dir.chdir oldpwd
    [stdout, stderr]
  end

  def execute_popen(code)
    require 'open3'
    stdin, stdout, stderr = Open3::popen3(*interpreter_command)
    stdin.puts code
    @evals.each{|x| stdin.puts x } unless @evals.empty?
    stdin.close
    [stdout, stderr]
  end

  def execute_script(code)
    path = File.expand_path("xmpfilter.tmpfile_#{Process.pid}.rb", Dir.tmpdir)
    File.open(path, "w"){|f| f.puts code}
    at_exit { File.unlink path if File.exist? path}
    stdout_path, stderr_path = (1..2).map do |i|
      fname = "xmpfilter.tmpfile_#{Process.pid}-#{i}.rb"
      File.expand_path(fname, Dir.tmpdir)
    end
    args = *(interpreter_command << %["#{path}"] << "2>" << 
      %["#{stderr_path}"] << ">" << %["#{stdout_path}"])
    system(args.join(" "))
    
    [stdout_path, stderr_path].map do |fullname|
      f = File.open(fullname, "r")
      # at_exit {
      #   f.close unless f.closed?
      #   File.unlink fullname if File.exist? fullname
      # }
      f
    end
  end

  def execute(code)
    stdout, stderr = __send__ @interpreter_info.execute_method, code
    if block_given?
      begin
        yield stdout, stderr
      ensure
        for out in [stdout, stderr]
          path = out.path rescue nil
          out.close
#          File.unlink path if path
        end
      end
    else
      [stdout, stderr]
    end
  end

  def interpreter_command
    # BUG interpreter option arguments containing space are not
    # accepted. But it seems to be rare case.
    r = @interpreter.split + @interpreter_info.options
    r << "-d" if $DEBUG and @interpreter_info.accept_debug
    r << "-I#{@include_paths.join(":")}" if @interpreter_info.accept_include_paths and !@include_paths.empty?
    @libs.each{|x| r << "-r#{x}" } unless @libs.empty?
    (r << "-").concat @options unless @options.empty?
    r
  end

  def extract_data(output)
    results = Hash.new{|h,k| h[k] = []}
    exceptions = Hash.new{|h,k| h[k] = []}
    bindings = Hash.new{|h,k| h[k] = []}
    output.grep(XMP_RE).each do |line|
      result_id, op, result = XMP_RE.match(line).captures
      case op
      when "=>"
        klass, value = /(\S+)\s+(.*)/.match(result).captures
        results[result_id.to_i] << [klass, value.gsub(/PPPROTECT/, "\n")]
      when "~>"
        exceptions[result_id.to_i] << result
      when "==>"
        bindings[result_id.to_i] << result unless result.index(VAR) 
      end
    end
    RuntimeData.new(results, exceptions, bindings)
  end

  def final_decoration(code, output)
    warnings = {}
    output.join.grep(WARNING_RE).map do |x|
      md = WARNING_RE.match(x)
      warnings[md[1].to_i] = md[2]
    end
    idx = 0
    ret = code.map do |line|
      w = warnings[idx+=1]
      if @warnings
        w ? (line.chomp + " # !> #{w}") : line
      else
        line
      end
    end
    output = output.reject{|x| /^-:[0-9]+: warning/.match(x)}
    if exception = /^-e?:[0-9]+:.*|^(?!!XMP)[^\n]+:[0-9]+:in .*/m.match(output.join)
      err = exception[0]
      err.gsub!(Regexp.union(@stdin_path), '-') if @stdin_path
      ret << err.map{|line| "# ~> " + line }
    end
    ret
  end

  def oneline_ize(code)
    "((" + code.gsub(/\r?\n|\r/, ';') + "));#{@postfix}\n"
  end

  def debugprint(*args)
    $stderr.puts(*args) if $DEBUG
  end
end # clas XMPFilter

class XMPAddMarkers < XMPFilter
  def self.run(code, opts)
    new(opts).add_markers(code, opts[:min_codeline_size])
  end
end

end
