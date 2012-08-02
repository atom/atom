require 'test/unit'

module ScriptConfig
  DIR      = File.join(File.expand_path(File.dirname(__FILE__)))
  SCRIPT   = File.join(DIR, "..", "lib", "method_analyzer.rb")
  DATAFILE = File.join(DIR, "data", "method_analyzer-data.rb")
end

class MethodAnalyzerTextOutput < Test::Unit::TestCase
  include ScriptConfig

  # test (find-sh "ruby -r../method_analyzer data/method_analyzer-data.rb")

  # attr_accessor is actually Module#attr_accessor.
  # But `f?ri Module.attr_accessor' answers correctly.
  expected = <<XXX
method fullnames
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:8:Fixnum#+
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:17:String#length
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:20:Time.now Time#initialize
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:21:Time#year Time#month Time#day Array#<<
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:22:Class.new Object#initialize
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:23:A#a
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:24:Class.new B#initialize
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:25:A#a
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:26:B#b
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:27:A#a B#b
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:28:A#a B#b Fixnum#+
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:29:A.foo
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:30:A.foo
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:31:B#bb=
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:32:B#bb

method definitions
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:3:A.foo
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:7:A#a
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:12:B#initialize
/m/home/rubikitch/src/xmpfilter/test/data/method_analyzer-data.rb:16:B#b
XXX

  def self.strip_dir(output)
    output.gsub(/^.+(method_analyzer-data)/, '\1')
  end

  def self.split_output(output)
    strip_dir(output).split(/\n\n/,2)
  end

  @@fullnames_expected, @@definitions_expected = split_output expected

  actual = strip_dir `ruby -r#{SCRIPT}  '#{DATAFILE}'`
  @@fullnames_actual, @@definitions_actual = split_output actual


  def test_plain_fullnames
    assert_equal @@fullnames_expected, @@fullnames_actual
  end
  
  def test_plain_definitions
    assert_equal @@definitions_expected, @@definitions_actual
  end
  
end

class MethodAnalyzerMarshalOutput < Test::Unit::TestCase
  include ScriptConfig

  METHOD_ANALYSIS = File.join(DIR, "method_analysis")
  at_exit { File.unlink METHOD_ANALYSIS rescue nil}

  def write_temp_file(str, file)
    file.replace File.expand_path(file)
    at_exit { File.unlink file }
    open(file, "w"){ |f| f.write(str) }
  end

  def test_marshal_merged
    begin
      ENV['METHOD_ANALYZER_FORMAT'] = 'marshal'
      @pwd = Dir.pwd
      Dir.chdir DIR
      a = write_temp_file "z=1+2", "mergeA.rb"
      system "ruby -r#{SCRIPT} mergeA.rb"
      method_analysis = Marshal.load(File.read(METHOD_ANALYSIS))
      assert_equal ["Fixnum#+"],     method_analysis[File.join(DIR, "mergeA.rb")][1]
    ensure
      ENV.delete 'METHOD_ANALYZER_FORMAT'
      Dir.chdir @pwd
    end
  end

  def test_marshal_merged
    begin
      ENV['METHOD_ANALYZER_FORMAT'] = 'marshal'
      @pwd = Dir.pwd
      Dir.chdir DIR
      
      b = write_temp_file "[].empty?", "mergeB.rb"
      system "ruby -r#{SCRIPT} mergeB.rb"
      method_analysis = Marshal.load(File.read(METHOD_ANALYSIS))
      assert_equal ["Array#empty?"], method_analysis[File.join(DIR, "mergeB.rb")][1]
    ensure
      ENV.delete 'METHOD_ANALYZER_FORMAT'
      Dir.chdir @pwd
    end
  end
end
