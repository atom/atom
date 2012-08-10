require 'test/unit'

module TestFunctional
  DIR = File.expand_path(File.dirname(__FILE__))
  LIBDIR = File.expand_path(DIR + '/../lib')
  
  module DefineFunctionalTests
    def define_functional_tests(bin, exec, tests)
      tests.each_pair do |test, opts|
        define_method("test_#{test}") do
          
          output = `ruby -I#{LIBDIR} #{exec} #{opts.join(" ")} #{DIR}/data/#{test}-input.rb`
          outputfile = "#{DIR}/data/#{test}-output.rb"
          taffile = "#{DIR}/data/#{bin}/#{test}.taf"
          open(taffile, "w") do |f|
            f.puts "=========="
            f.puts test
            f.puts "=========="
            f.puts bin + " " + opts.join(" ")
            f.puts "=========="
            f.puts File.read("#{DIR}/data/#{test}-input.rb")
            f.puts "=========="
            f.puts File.read("#{DIR}/data/#{test}-output.rb")
          end
#          assert_equal(File.read(outputfile), output)
        end
      end 
    end
  end

  class TestXmpfilter < Test::Unit::TestCase
    extend DefineFunctionalTests
    tests = {
      :simple_annotation => [], :unit_test => ["-u"], :rspec => ["-s"],
      :no_warnings => ["--no-warnings"], :bindings => ["--poetry", "-u"],
      :add_markers => ["-m"], :unit_test_rbtest => ["-u", "--rbtest"],
      :unit_test_detect_rbtest => ["-u", "--detect-rbtest"],
      :unit_test_detect_rbtest2 => ["--detect-rbtest"],
    }
    define_functional_tests "xmpfilter", File.expand_path(DIR + '/../bin/xmpfilter'), tests
  end

  class TestRctComplete < Test::Unit::TestCase
    extend DefineFunctionalTests
    tests = {
      :completion_rbtest => [ "--rbtest", "--line=6" ],
      :completion_detect_rbtest => [ "--detect-rbtest", "--line=6" ],
      :completion_detect_rbtest2 => [ "--detect-rbtest", "--line=1" ],
    }
    define_functional_tests "rct-complete", File.expand_path(DIR + '/../bin/rct-complete'), tests
  end

  class TestRctDoc < Test::Unit::TestCase
    extend DefineFunctionalTests
    tests = {
      :doc_rbtest => [ "--rbtest", "--line=6" ],
      :doc_detect_rbtest => [ "--detect-rbtest", "--line=1" ],
      :doc_detect_rbtest2 => [ "--detect-rbtest", "--line=6" ],
    }
    define_functional_tests "rct-doc", File.expand_path(DIR + '/../bin/rct-doc'), tests
  end


  # Other tests are in test_run.rb
  class TestRctCompleteTDC < Test::Unit::TestCase
    test = :completion_in_method
    inputfile = "#{DIR}/data/#{test}-input.rb"
    outputfile = "#{DIR}/data/#{test}-output.rb"
    test_script = "#{DIR}/data/#{test}-test.rb"
    common_opts = ["--filename #{inputfile}", "--line 2"]
    right_output = File.read(outputfile)
    wrong_output = "\n"

    tests = {
      :completion_in_method__testscript =>
        [ common_opts + ["-t #{test_script}"], right_output ],
      :completion_in_method__testmethod =>
        [ common_opts + ["-t #{test_script}@test_fooz"], right_output ],
      :completion_in_method__wrong_testmethod =>
        [ common_opts + ["-t #{test_script}@test_NOT_FOUND"], wrong_output ],
    }
    exec = File.expand_path(DIR + '/../bin/rct-complete')
#     tests.each_pair do |test, (opts, expected)|
#       define_method("test_#{test}") do 
#         output = `ruby -I#{LIBDIR} #{exec} #{opts.join(" ")} #{inputfile}`
        
#         taffile = "#{DIR}/data/#{bin}/#{test}.taf"
#         open(taffile, "w") do |f|
#           f.puts "=========="
#           f.puts test
#           f.puts "=========="
#           f.puts bin + " " + opts.join(" ")
#           f.puts "=========="
#           f.puts File.read("#{DIR}/data/#{test}-input.rb")
#           f.puts "=========="
#           f.puts File.read("#{DIR}/data/#{test}-output.rb")
#         end
#       end
#     end

    test=:completion_in_method__testscript
    define_method("test_#{test}") do
      taffile = "#{DIR}/data/rct-complete-TDC/completion_in_method__testscript.taf"
      open(taffile, "w") do |f|
        opts = tests[test]
        f.puts "=========="
        f.puts test
        f.puts "=========="
        f.puts "rct-complete " + opts.join(" ")
        f.puts "=========="
        test0 = :completion_in_method
        f.puts File.read("#{DIR}/data/#{test0}-input.rb")
        f.puts "=========="
        f.puts File.read("#{DIR}/data/#{test0}-output.rb")
        f.puts "=========="
        f.puts File.read("#{DIR}/data/#{test0}-test.rb")
      end
      
    end

    test=:completion_in_method__testmethod
    define_method("test_#{test}") do
      taffile = "#{DIR}/data/rct-complete-TDC/completion_in_method__testmethod.taf"
      open(taffile, "w") do |f|
        opts = tests[test]
        f.puts "=========="
        f.puts test
        f.puts "=========="
        f.puts "rct-complete " + opts.join(" ")
        f.puts "=========="
        test0 = :completion_in_method
        f.puts File.read("#{DIR}/data/#{test0}-input.rb")
        f.puts "=========="
        f.puts File.read("#{DIR}/data/#{test0}-output.rb")
        f.puts "=========="
        f.puts File.read("#{DIR}/data/#{test0}-test.rb")
      end
      
    end

    test=:completion_in_method__wrong_testmethod
    define_method("test_#{test}") do
      taffile = "#{DIR}/data/rct-complete-TDC/completion_in_method__wrong_testmethod.taf"
      open(taffile, "w") do |f|
        opts = tests[test]
        f.puts "=========="
        f.puts test
        f.puts "=========="
        f.puts "rct-complete " + opts.join(" ")
        f.puts "=========="
        test0 = :completion_in_method
        f.puts File.read("#{DIR}/data/#{test0}-input.rb")
        f.puts "=========="
        f.puts 
        f.puts "=========="
        f.puts File.read("#{DIR}/data/#{test0}-test.rb")
      end
      
    end

  end
end
