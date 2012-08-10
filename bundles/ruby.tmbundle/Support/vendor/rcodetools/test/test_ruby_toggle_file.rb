require 'fileutils'
require 'test/unit'
require 'ruby_toggle_file'
require 'tmpdir'

class TestRubyToggleFile < Test::Unit::TestCase
  WORK_DIR = "#{Dir.tmpdir}/zdsfwfwejiotest".freeze
  FileUtils.rm_rf WORK_DIR

  def teardown
    FileUtils.rm_rf WORK_DIR
  end

  def create(*files)
    for file in files.map{|f| _(f) }
      FileUtils.mkpath(File.dirname(file))
      open(file,"w"){}
    end
  end

  def _(path)                   # make full path
    WORK_DIR + "/" + path
  end

  ###########################################################################
  # naming convention                                                       #
  # test_METHOD__EXISTP__IMPLEMENTDIR_TESTDIR                               #
  ###########################################################################
  def test_test_file__exist__lib_test
    create "lib/zero.rb", "test/test_zero.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/test_zero.rb"), rtf.ruby_toggle_file(_("lib/zero.rb"))
  end

  def test_test_file__exist__libone_testone
    create "lib/one/one.rb", "test/one/test_one.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/one/test_one.rb"), rtf.ruby_toggle_file(_("lib/one/one.rb"))
  end

  def test_test_file__exist__libtwo_test
    create "lib/two/two.rb", "test/test_two.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/test_two.rb"), rtf.ruby_toggle_file(_("lib/two/two.rb"))
  end

  def test_test_file__exist__top_test
    create "three.rb", "test_three.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test_three.rb"), rtf.ruby_toggle_file(_("three.rb"))
  end

  def test_test_file__not_exist__top
    create "four.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test_four.rb"), rtf.ruby_toggle_file(_("four.rb"))
  end

  def test_test_file__not_exist__lib
    create "lib/five.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/test_five.rb"), rtf.ruby_toggle_file(_("lib/five.rb"))
  end

  def test_test_file__not_exist__libsixsix
    create "lib/six/six/six.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/six/six/test_six.rb"), rtf.ruby_toggle_file(_("lib/six/six/six.rb"))
  end

  def test_implementation_file__exist__lib_test
    create "lib/zero.rb", "test/test_zero.rb"
    rtf = RubyToggleFile.new
    assert_equal _("lib/zero.rb"), rtf.ruby_toggle_file(_("test/test_zero.rb"))
  end

  def test_implementation_file__exist__libone_testone
    create "lib/one/one.rb", "test/one/test_one.rb"
    rtf = RubyToggleFile.new
    assert_equal _("lib/one/one.rb"), rtf.ruby_toggle_file(_("test/one/test_one.rb"))
  end

  def test_implementation_file__exist__libtwo_test
    create "lib/two/two.rb", "test/test_two.rb"
    rtf = RubyToggleFile.new
    assert_equal _("lib/two/two.rb"), rtf.ruby_toggle_file(_("test/test_two.rb"))
  end

  def test_implementation_file__exist__top_test
    create "three.rb", "test_three.rb"
    rtf = RubyToggleFile.new
    assert_equal _("three.rb"), rtf.ruby_toggle_file(_("test_three.rb"))
  end

  def test_implementation_file__not_exist__none_top
    create "test_seven.rb"
    rtf = RubyToggleFile.new
    assert_equal _("seven.rb"), rtf.ruby_toggle_file(_("test_seven.rb"))
  end

  def test_implementation_file__not_exist__none_test
    create "test/test_eight.rb"
    rtf = RubyToggleFile.new
    assert_equal _("lib/eight.rb"), rtf.ruby_toggle_file(_("test/test_eight.rb"))
  end

  def test_implementation_file__not_exist__none_testninenine
    create "test/nine/nine/nine.rb"
    rtf = RubyToggleFile.new
    assert_equal _("lib/nine/nine/nine.rb"), rtf.ruby_toggle_file(_("test/nine/nine/test_nine.rb"))
  end

  ###########################################################################
  # Rails test                                                              #
  ###########################################################################
  def test_test_file__rails_controllers
    create "app/controllers/c.rb", "test/functional/c_test.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/functional/c_test.rb"), rtf.ruby_toggle_file(_("app/controllers/c.rb"))
  end

  def test_test_file__rails_models
    create "app/models/m.rb", "test/unit/m_test.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/unit/m_test.rb"), rtf.ruby_toggle_file(_("app/models/m.rb"))
  end

  def test_test_file__rails_lib
    create "lib/l.rb", "test/unit/test_l.rb", "app/models/m.rb"
    rtf = RubyToggleFile.new
    assert_equal _("test/unit/test_l.rb"), rtf.ruby_toggle_file(_("lib/l.rb"))
  end


  def test_implementation_file__rails_controllers
    create "app/controllers/c.rb", "test/functional/c_test.rb"
    rtf = RubyToggleFile.new
    assert_equal _("app/controllers/c.rb"), rtf.ruby_toggle_file(_("test/functional/c_test.rb"))
  end

  def test_implementation_file__rails_models
    create "app/models/m.rb", "test/unit/m_test.rb"
    rtf = RubyToggleFile.new
    assert_equal _("app/models/m.rb"), rtf.ruby_toggle_file(_("test/unit/m_test.rb"))
  end

  def test_implementation_file__rails_lib
    create "lib/l.rb", "test/unit/test_l.rb", "app/models/m.rb"
    rtf = RubyToggleFile.new
    assert_equal _("lib/l.rb"), rtf.ruby_toggle_file(_("test/unit/test_l.rb"))
  end
end


class TestRunHooksWithArgsUntilSuccess < Test::Unit::TestCase
  def m001(x) nil end
  private
  def m002(x) false end
  def m003(x) 100*x end
  def m004(x) 200 end

  public
  def test_run_hooks_with_args_until_success__m003
    assert_equal 1000, run_hooks_with_args_until_success(/^m\d+$/, 10)
  end

  def test_run_hooks_with_args_until_success__m001
    assert_nil   run_hooks_with_args_until_success(/^m001$/, 10)
  end

  def test_run_hooks_with_args_until_success__m004
    assert_equal 200, run_hooks_with_args_until_success(/^m004$/, 10)
  end
end
