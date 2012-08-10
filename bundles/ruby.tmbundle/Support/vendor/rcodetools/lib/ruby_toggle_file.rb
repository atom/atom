
# The name is taken from EmacsLisp
def run_hooks_with_args_until_success(regexp, *args)
  private_methods(true).concat(methods(true)).grep(regexp).sort.each do |m|
    _ = __send__(m, *args)
    return _ if _
  end
  nil
end

class RubyToggleFile
  def ruby_toggle_file(file)
    if File.basename(file) =~ /(?:^test_|_test\.rb$)/
      implementation_file(file)
    else
      test_file(file)
    end
  end

  LIB_RE = %r!/lib/(.+)\.rb$!
  TEST_RE = %r!/test/(.+/)?test_(.+)\.rb$!

  def test_file(implementation)
    if m = LIB_RE.match(implementation)
      dir, node = File.split m[1]
      dir = (dir == '.') ? nil : dir+"/"
    else
      dir = node = nil
    end
    run_hooks_with_args_until_success %r/^test_file_/, implementation, m&&(m.pre_match+"/"), dir, node
  end

  def implementation_file(test)
    m = TEST_RE.match(test)
    run_hooks_with_args_until_success %r/^implementation_file_/, test, m&&(m.pre_match+"/"), m&&m[1], m&&m[2]
  end

#  private
  def exist(file)
    file if File.exist? file
  end

  RAILS_MVC2TESTNAME = { 'models' => 'unit', 'controllers' => 'functional' }
  RAILS_TESTNAME2MVC = RAILS_MVC2TESTNAME.invert
  def test_file_00_rails(implementation, basedir, dir, node) # rails
    if m = %r!app/(models|controllers)/(.+)\.rb$!.match(implementation)
      "%stest/%s/%s_test.rb" % [ m.pre_match, RAILS_MVC2TESTNAME[m[1]], m[2] ]
    end
  end

  def test_file_05_rails_lib(implementation, basedir, dir, node)
    if basedir and File.directory?( File.join(basedir, "app") )
      "#{basedir}test/unit/test_#{node}.rb"
    end
  end

  def test_file_10_no_match(implementation, basedir, dir, node)
    if [basedir, dir, node].all?{|x| x.nil?}
      "#{File.dirname(implementation)}/test_#{File.basename(implementation)}"
    end
  end

  def test_file_20_simple(implementation, basedir, dir, node) # test/test_NODE.rb
    exist "#{basedir}test/test_#{node}.rb"
  end

  def test_file_30_flat(implementation, basedir, dir, node) # lib/XXX/NODE.rb -> test/test_NODE.rb
    exist "#{basedir}test/test_#{node}.rb" if dir
  end

  def test_file_99_autotest_default(implementation, basedir, dir, node) # lib/XXX/NODE.rb -> test/XXX/test_NODE.rb
    "#{basedir}test/#{dir}test_#{node}.rb"
  end

  def implementation_file_00_rails(test, basedir, dir, node)
    if m = %r!test/(unit|functional)/(.+)_test.rb$!.match(test)
      "%sapp/%s/%s.rb" % [ m.pre_match, RAILS_TESTNAME2MVC[m[1]], m[2] ]
    end
  end

  def implementation_file_10_no_match(test, basename, dir, node)
    if dir == nil and node == nil and test =~ %r!/test_(.+)\.rb$!
      test.sub("/test_", "/")
    end
  end

  def implementation_file_20(test, basedir, dir, node)
    exist("#{basedir}lib/#{dir}#{node}.rb")
  end

  def implementation_file_30_flat(test, basedir, dir, node)
    Dir[ "#{basedir}lib/**/#{node}.rb" ].first
  end

  def implementation_file_99_default(test, basedir, dir, node)
    "#{basedir}lib/#{dir}#{node}.rb"
  end

end
