require 'test/unit'
require 'tempfile'
class TestFunctional < Test::Unit::TestCase
  def self.parse_taf(filename)
    open(filename) do |io|
      delimiter=Regexp.union(io.gets)
      io.read.split(delimiter)
    end
  end

  def tempfile_with_contents(contents)
    input = Tempfile.new("rct-test")
    input.write(contents)
    input.close
    input.path
  end

  DIR = File.expand_path(File.dirname(__FILE__))
  LIBDIR = File.expand_path(DIR + '/../lib')
  BINDIR = File.expand_path(DIR + '/../bin')

  # rct-complete-TDC 
  %w[xmpfilter rct-complete rct-doc].each do |subdir|
    Dir["#{DIR}/data/#{subdir}/*.taf"].each do |taf|
      desc, cmdline, input, output = parse_taf(taf)
      [desc, cmdline].each{|x| x.chomp! }
      define_method("test_#{desc}") do
        inputfile = tempfile_with_contents(input)
        actual_output = `ruby -I#{LIBDIR} #{BINDIR}/#{cmdline} #{inputfile}`
        assert_equal output, actual_output
      end
    end
  end
  
  # TODO
  Dir["#{DIR}/data/rct-complete-TDC/*.taf"].each do |taf|
    desc, cmdline, input, output, test = parse_taf(taf)
    [desc, cmdline].each{|x| x.chomp! }
    define_method("test_#{desc}") do
      inputfile = tempfile_with_contents(input)
      testfile = tempfile_with_contents(test)
      actual_output = `ruby -I#{LIBDIR} #{BINDIR}/#{cmdline % [inputfile, testfile]} #{inputfile}`
      assert_equal output, actual_output
    end
  end

end
