
require 'test/unit'
$: << ".." << "../lib"
require "rcodetools/xmpfilter"
require 'rubygems'
require 'mocha'

class TestXMPFilter < Test::Unit::TestCase
  include Rcodetools
  def test_extract_data__results
    marker = XMPFilter::MARKER
    str = <<-EOF
#{marker}[1] => Fixnum 42
#{marker}[1] => Fixnum 0
#{marker}[1] ==> var
#{marker}[1] ==> var2
#{marker}[4] ==> var3
#{marker}[2] ~> some exception
#{marker}[10] => Fixnum 42
    EOF
    xmp = XMPFilter.new
    data = xmp.extract_data(str)
    assert_equal([[1, [["Fixnum", "42"], ["Fixnum", "0"]]], [10, [["Fixnum", "42"]]]], data.results.sort)
  end

  def test_extract_data__exceptions
    marker = XMPFilter::MARKER
    str = <<-EOF
#{marker}[1] => Fixnum 42
#{marker}[1] => Fixnum 0
#{marker}[1] ==> var
#{marker}[1] ==> var2
#{marker}[4] ==> var3
#{marker}[2] ~> some exception
#{marker}[10] => Fixnum 42
    EOF
    xmp = XMPFilter.new
    data = xmp.extract_data(str)
    assert_equal([[2, ["some exception"]]], data.exceptions.sort)
  end

  def test_extract_data__bindings
    marker = XMPFilter::MARKER
    str = <<-EOF
#{marker}[1] => Fixnum 42
#{marker}[1] => Fixnum 0
#{marker}[1] ==> var
#{marker}[1] ==> var2
#{marker}[4] ==> var3
#{marker}[2] ~> some exception
#{marker}[10] => Fixnum 42
    EOF
    xmp = XMPFilter.new
    data = xmp.extract_data(str)
    assert_equal([[1, ["var", "var2"]], [4, ["var3"]]], data.bindings.sort)
  end

  def test_interpreter_command
    xmp = XMPFilter.new(:interpreter=>"ruby", :detect_rct_fork => false)
    assert_equal(%w[ruby -w], xmp.interpreter_command)
  end

  def test_interpreter_command_detect_rct_fork
    Fork.stubs(:run?).returns true
    xmp = XMPFilter.new(:interpreter=>"ruby", :detect_rct_fork => true)
    assert_equal(%w[ruby -S rct-fork-client], xmp.interpreter_command)
  end

  def test_interpreter_command_use_rbtest
    xmp = XMPFilter.new(:interpreter=>"ruby", :use_rbtest => true)
    assert_equal(%w[ruby -S rbtest], xmp.interpreter_command)
  end

  def test_initialize__test_script_1
    XMPFilter.any_instance.stubs(:safe_require_code).returns("require 'test/unit'")
    xmp = XMPFilter.new(:test_script=>"/path/to/test/test_ruby_toggle_file.rb",
                         :test_method=>"test_implementation_file_file_exist",
                         :filename=>"/path/to/lib/ruby_toggle_file.rb")

    evals_expected = [
      %q!$LOADED_FEATURES << "ruby_toggle_file.rb"!,
      %q!require 'test/unit'!,
      %q!load "/path/to/test/test_ruby_toggle_file.rb"!,
      %q!Test::Unit::AutoRunner.run(false, nil, ["-n", "test_implementation_file_file_exist"])!
    ]
    assert_equal evals_expected, xmp.instance_variable_get(:@evals)
  end

  def test_initialize__test_script_2
    XMPFilter.any_instance.stubs(:safe_require_code).returns("require 'test/unit'")
    xmp = XMPFilter.new(:test_script=>"/path/to/test_ruby_toggle_file.rb",
                         :test_method=>"test_implementation_file_file_exist",
                         :filename=>"/path/to/ruby_toggle_file.rb")

    evals_expected = [
      %q!$LOADED_FEATURES << "ruby_toggle_file.rb"!,
      %q!require 'test/unit'!,
      %q!load "/path/to/test_ruby_toggle_file.rb"!,
      %q!Test::Unit::AutoRunner.run(false, nil, ["-n", "test_implementation_file_file_exist"])!
    ]
    assert_equal evals_expected, xmp.instance_variable_get(:@evals)
  end

  def test_initialize__test_script_3
    test_script = File.join(File.dirname(__FILE__), "data/sample_test_script.rb")
    filename = File.join(File.dirname(__FILE__), "data/sample.rb")
    XMPFilter.any_instance.stubs(:safe_require_code).returns("require 'test/unit'")
    xmp = XMPFilter.new(:test_script=>test_script, :test_method=>"4", :filename=>filename)

    evals_expected = [
      %q!$LOADED_FEATURES << "sample.rb"!,
      %q!require 'test/unit'!,
      %Q!load #{test_script.dump}!,
      %q!Test::Unit::AutoRunner.run(false, nil, ["-n", "test_sample0"])!
    ]
    assert_equal evals_expected, xmp.instance_variable_get(:@evals)
  end

  def test_initialize__test_script__filename_eq_test_script
    test_script = File.join(File.dirname(__FILE__), "data/sample_test_script.rb")
    filename = test_script
    xmp = XMPFilter.new(:test_script=>test_script, :test_method=>"4", :filename=>filename)

    evals_expected = [
      %q!Test::Unit::AutoRunner.run(false, nil, ["-n", "test_sample0"])!
    ]
    assert_equal evals_expected, xmp.instance_variable_get(:@evals)
  end

  def test_get_test_method_from_lineno
    file = File.join(File.dirname(__FILE__), "data/sample_test_script.rb")
    xmp = XMPFilter.new
    assert_equal("test_sample0", xmp.get_test_method_from_lineno(file, 4))
    assert_equal("test_sample1", xmp.get_test_method_from_lineno(file, 7))
    assert_equal("test_sample1", xmp.get_test_method_from_lineno(file, 8))
    assert_equal(nil, xmp.get_test_method_from_lineno(file, 1))
  end

  # Use methods to avoid confusing syntax highlighting
  def beg() "=begin" end
  def ed()  "=end"   end
  
  def test_s_detect_rbtest_1
    rbtest_script_1 = <<XXX
#{beg} test_0
assert f(10)
#{ed}
def f(x) x*100 end
XXX

    opts = {:detect_rbtest => true}
    assert_equal true, XMPFilter.detect_rbtest(rbtest_script_1, opts)
    assert_equal true, opts[:use_rbtest]
    opts = {:detect_rbtest => false}
    assert_equal false, XMPFilter.detect_rbtest(rbtest_script_1, opts)
    assert_equal false, opts[:use_rbtest]
    opts = {:detect_rbtest => false, :use_rbtest => true}
    assert_equal true, XMPFilter.detect_rbtest(rbtest_script_1, opts)
    assert_equal true, opts[:use_rbtest]
  end

  def test_s_detect_rbtest_2
    rbtest_script_2 = <<XXX
def f(x) x*100 end
#{beg} test_0
assert f(10)
#{ed}
XXX
    opts = {:detect_rbtest => true}
    assert_equal true, XMPFilter.detect_rbtest(rbtest_script_2, opts)
    assert_equal true, opts[:use_rbtest]
    opts = {:detect_rbtest => false}
    assert_equal false, XMPFilter.detect_rbtest(rbtest_script_2, opts)
    assert_equal false, opts[:use_rbtest]
  end
  
  def test_s_detect_rbtest_3
    no_rbtest_script = <<XXX
def f(x) x*100 end
XXX

    opts = {:detect_rbtest => true}
    assert_equal false, XMPFilter.detect_rbtest(no_rbtest_script, opts)
    assert_equal false, opts[:use_rbtest]
    opts = {:detect_rbtest => false}
    assert_equal false, XMPFilter.detect_rbtest(no_rbtest_script, opts)
    assert_equal false, opts[:use_rbtest]
  end

end

class TestTempScript < Test::Unit::TestCase
  def test(script)
    Rcodetools::XMPFilter.new.__send__(:split_shbang,script)
  end

  def test_none
    assert_equal [[], ["1\n"]], test(<<EOS)
1
EOS
  end
  def test_shbang
    assert_equal [["#!/usr/bin/ruby\n"], ["1\n"]], test(<<EOS)
#!/usr/bin/ruby
1
EOS
  end
  def test_magic_comment
    assert_equal [["# -*- coding: utf-8 -*-\n"], ["1\n"]], test(<<EOS)
# -*- coding: utf-8 -*-
1
EOS
  end
  def test_both
    assert_equal [["#!/usr/bin/ruby\n", "# -*- coding: utf-8 -*-\n"], ["1\n"]], test(<<EOS)
#!/usr/bin/ruby
# -*- coding: utf-8 -*-
1
EOS
  end
end
