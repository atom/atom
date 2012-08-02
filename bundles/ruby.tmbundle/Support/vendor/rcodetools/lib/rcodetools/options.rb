require 'optparse'

module Rcodetools
# Domain specific OptionParser extensions
module OptionHandler
  def set_banner
    self.banner = "Usage: #{$0} [options] [inputfile] [-- cmdline args]"
  end

  def handle_position(options)
    separator ""
    separator "Position options:"
    on("--line=LINE", "Current line number.") do |n|
      options[:lineno] = n.to_i
    end
    on("--column=COLUMN", "Current column number in BYTE.") do |n|
      options[:column] = n.to_i
    end
    on("-t TEST", "--test=TEST",
       "Execute test script. ",
       "TEST is TESTSCRIPT, TESTSCRIPT@TESTMETHOD, or TESTSCRIPT@LINENO.",
       "You must specify --filename option.") do |t|
      options[:test_script], options[:test_method] = t.split(/@/)
    end
    on("--filename=FILENAME", "Filename of standard input.") do |f|
      options[:filename] = f
    end
  end

  def handle_interpreter(options)
    separator ""
    separator "Interpreter options:"
    on("-S FILE", "--interpreter FILE", "Use interpreter FILE.") do |interpreter|
      options[:interpreter] = interpreter
    end
    on("-I PATH", "Add PATH to $LOAD_PATH") do |path|
      options[:include_paths] << path
    end
    on("--dev", "Add this project's bin/ and lib/ to $LOAD_PATH.",
       "A directory with a Rakefile is considered a project base directory.") do
      auto_include_paths(options[:include_paths], Dir.pwd)
    end
    on("-r LIB", "Require LIB before execution.") do |lib|
      options[:libs] << lib
    end
    on("-e EXPR", "--eval=EXPR", "--stub=EXPR", "Evaluate EXPR after execution.") do |expr|
      options[:evals] << expr
    end
    on("--fork", "Use rct-fork-client if rct-fork is running.") do 
      options[:detect_rct_fork] = true
    end
    on("--rbtest", "Use rbtest.") do
      options[:use_rbtest] = true
    end
    on("--detect-rbtest", "Use rbtest if '=begin test_*' blocks exist.") do
      options[:detect_rbtest] = true
    end
  end

  def handle_misc(options)
    separator ""
    separator "Misc options:"
    on("--cd DIR", "Change working directory to DIR.") do |dir|
      options[:wd] = dir
    end
    on("--debug", "Write transformed source code to xmp-tmp.PID.rb.") do
      options[:dump] = "xmp-tmp.#{Process.pid}.rb"
    end
    on("--tmpfile", "--tempfile", "Use tmpfile instead of open3. (non-windows)") do
      options[:execute_ruby_tmpfile] = true
    end
    on("-w N", "--width N", Integer, "Set width of multi-line annotation. (xmpfilter only)") do |width|
      options[:width] = width
    end
    separator ""
    on("-h", "--help", "Show this message") do
      puts self
      exit
    end
    on("-v", "--version", "Show version information") do
      puts "#{File.basename($0)} #{XMPFilter::VERSION}"
      exit
    end
  end

  def auto_include_paths(include_paths, pwd)
    if pwd =~ %r!^(.+)/(lib|bin)!
      include_paths.unshift("#$1/lib").unshift("#$1/bin")
    elsif File.file? "#{pwd}/Rakefile" or File.file? "#{pwd}/rakefile"
      include_paths.unshift("#{pwd}/lib").unshift("#{pwd}/bin")
    end
  end
  module_function :auto_include_paths

end

def set_extra_opts(options)
  if idx = ARGV.index("--")
    options[:options] = ARGV[idx+1..-1]
    ARGV.replace ARGV[0...idx]
  else
    options[:options] = []
  end
end

def check_opts(options)
  if options[:test_script]
    unless options[:filename]
      $stderr.puts "You must specify --filename as well as -t(--test)."
      exit 1
    end
  end
end

DEFAULT_OPTIONS = {
  :interpreter       => "ruby",
  :options => ["hoge"],
  :min_codeline_size => 50,
  :width             => 79,
  :libs              => [],
  :evals             => [],
  :include_paths     => [],
  :dump              => nil,
  :wd                => nil,
  :warnings          => true,
  :use_parentheses   => true,
  :column            => nil,
  :output_stdout     => true,
  :test_script       => nil,
  :test_method       => nil,
  :detect_rct_fork   => false,
  :use_rbtest        => false,
  :detect_rbtest     => false,
  :execute_ruby_tmpfile => false,
  }
end                             # /Rcodetools
