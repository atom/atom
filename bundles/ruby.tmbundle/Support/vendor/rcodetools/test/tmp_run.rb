require 'test/unit'
require 'rcodetools/xmpfilter'
require 'rcodetools/xmptestunitfilter'
require 'rcodetools/completion'
require 'rcodetools/doc'
require 'rcodetools/options'
require 'stringio'

class TestRun < Test::Unit::TestCase
  include Rcodetools
  DIR = File.expand_path(File.dirname(__FILE__))

  tests = {
#    :rspec_poetry      => {:klass => XMPRSpecFilter,    :interpreter     => "spec", :use_parentheses => false},
    :rspec_poetry => ["xmpfilter", "-s --poetry"],
#    :unit_test_poetry  => {:klass => XMPTestUnitFilter, :use_parentheses => false},
    :unit_test_poetry => ["xmpfilter", "-u --poetry"],
    
#    :completion       => {:klass => XMPCompletionFilter,      :lineno => 1},
    :completion => ["rct-complete", "-C --line=1"],
#    :completion_emacs => {:klass => XMPCompletionEmacsFilter, :lineno => 1},
    :completion_emacs => ["rct-complete", "--completion-emacs --line=1"],
#    :completion_emacs_icicles => {:klass => XMPCompletionEmacsIciclesFilter, :lineno => 1},
    :completion_emacs_icicles => ["rct-complete","--completion-emacs-icicles --line=1"],
#    :completion_class_info => {:klass => XMPCompletionClassInfoFilter, :lineno => 1},
    :completion_class_info => ["rct-complete", "--completion-class-info --line=1"],
#    :completion_class_info_no_candidates => {:klass => XMPCompletionClassInfoFilter, :lineno => 1},
    :completion_class_info_no_candidates => ["rct-complete", "--completion-class-info --line=1"],
    
#     :doc      => {:klass => XMPDocFilter,     :lineno => 1},
#     :refe     => {:klass => XMPReFeFilter,    :lineno => 1},
#     :ri       => {:klass => XMPRiFilter,      :lineno => 1},
#     :ri_emacs => {:klass => XMPRiEmacsFilter, :lineno => 1},
#     :ri_vim   => {:klass => XMPRiVimFilter,   :lineno => 1},
    :doc => ["rct-doc", "-D --line=1"],
    :refe => ["rct-doc", "--refe --line=1"],
    :ri => ["rct-doc", "--ri --line=1"],
    :ri_emacs => ["rct-doc", "--ri-emacs --line=1"],
    :ri_vim => ["rct-doc", "--ri-vim --line=1"],
    
  }
  DIR = File.expand_path(File.dirname(__FILE__))
  LIBDIR = File.expand_path(DIR + '/../lib')

  tests.each_pair do |test, (bin,opts)|
    define_method("test_#{test}") do
      inputfile = "#{DIR}/data/#{test}-input.rb"
      outputfile = "#{DIR}/data/#{test}-output.rb"

#       exec = File.expand_path(DIR + '/../bin/xmpfilter')
#       output = `ruby -I#{LIBDIR} #{exec} #{opts} #{DIR}/data/#{test}-input.rb`
#       outputfile = "#{DIR}/data/#{test}-output.rb"
      taffile = "#{DIR}/data/#{bin}/#{test}.taf"
      open(taffile, "w") do |f|
        f.puts "=========="
        f.puts test
        f.puts "=========="
        f.puts bin + " " + opts
        f.puts "=========="
        f.puts File.read("#{DIR}/data/#{test}-input.rb")
        f.puts "=========="
        f.puts File.read("#{DIR}/data/#{test}-output.rb")
      end
    end
  end 
end
