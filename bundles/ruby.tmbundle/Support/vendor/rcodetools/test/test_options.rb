$: << ".." << "../lib"
require 'rcodetools/options'
require 'test/unit'
require 'tmpdir'
require 'fileutils'

class TestOptionHandler < Test::Unit::TestCase
  include Rcodetools
  include OptionHandler

  def include_paths_check
    options = { :include_paths => [] }
    auto_include_paths options[:include_paths], Dir.pwd
    assert options[:include_paths].include?("#{@basedir}/lib")
    assert options[:include_paths].include?("#{@basedir}/bin")
  end

  def test_auto_include_paths
    Dir.chdir(Dir.tmpdir) do
      begin
        FileUtils.mkdir_p ["project", "project/lib/project", "project/bin", "project/share"]
        open("project/Rakefile","w"){}
        @basedir = File.expand_path "project"
        Dir.chdir("project/lib/project/") { include_paths_check }
        Dir.chdir("project/lib/") { include_paths_check }
        Dir.chdir("project/bin/") { include_paths_check }
        Dir.chdir("project/") { include_paths_check }
      ensure
        FileUtils.rm_rf "project"
      end
    end
  end
end
