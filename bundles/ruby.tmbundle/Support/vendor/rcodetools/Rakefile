
PKG_REVISION = ".0"

$:.unshift "lib" if File.directory? "lib"
require 'rcodetools/xmpfilter'
require 'rake/testtask'
include Rcodetools
RCT_VERSION  = XMPFilter::VERSION

desc "Run the unit tests in pure-Ruby mode ."
Rake::TestTask.new(:test) do |t|
  t.test_files = FileList['test/test*.rb']
  t.verbose = true
end

begin
  require 'rcov/rcovtask'
  desc "Run rcov."
  Rcov::RcovTask.new do |t|
    t.rcov_opts << "--xrefs"  # comment to disable cross-references
    t.test_files = FileList['test/test_*.rb'].to_a - ["test/test_functional.rb"]
    t.verbose = true
  end

  desc "Save current coverage state for later comparisons."
  Rcov::RcovTask.new(:rcovsave) do |t|
    t.rcov_opts << "--save"
    t.test_files = FileList['test/test_*.rb'].to_a - ["test/test_functional.rb"]
    t.verbose = true
  end
rescue LoadError
  # rcov is not installed
end
task :default => :test


#{{{ Package tasks
PKG_FILES = FileList[
  "bin/xmpfilter", "bin/rct-*", "bin/ruby-toggle-file", "bin/rbtest",
"lib/**/*.rb",
"CHANGES", "rcodetools.*", "icicles-rcodetools.el", "anything-rcodetools.el",
"README", "README.*", "THANKS", 
"Rakefile", "Rakefile.method_analysis",
"setup.rb",
"test/**/*.rb","test/**/*.taf"
]

begin
  require 'rake/gempackagetask'
  Spec = Gem::Specification.new do |s|
    s.name = "rcodetools"
    s.version = RCT_VERSION + PKG_REVISION
    s.summary = "rcodetools is a collection of Ruby code manipulation tools"
    s.description = <<EOF
rcodetools is a collection of Ruby code manipulation tools. 
It includes xmpfilter and editor-independent Ruby development helper tools,
as well as emacs and vim interfaces.

Currently, rcodetools comprises:
* xmpfilter: Automagic Test::Unit assertions/RSpec expectations and code annotations
* rct-complete: Accurate method/class/constant etc. completions
* rct-doc: Document browsing and code navigator
* rct-meth-args: Precise method info (meta-prog. aware) and TAGS generation
EOF
    s.files = PKG_FILES.to_a
    s.require_path = 'lib'
    s.author = "rubikitch and Mauricio Fernandez"
    s.email = %{"rubikitch" <rubikitch@ruby-lang.org>, "Mauricio Fernandez" <mfp@acm.org>}
    s.homepage = "http://eigenclass.org/hiki.rb?rcodetools"
    s.bindir = "bin"
    s.executables = %w[rct-complete rct-doc xmpfilter rct-meth-args]
    s.has_rdoc = true
    s.extra_rdoc_files = %w[README]
    s.rdoc_options << "--main" << "README" << "--title" << 'rcodetools'
    s.test_files = Dir["test/test_*.rb"]
    s.post_install_message = <<EOF

==============================================================================

rcodetools will work better if you use it along with FastRI, an alternative to
the standard 'ri' documentation browser which features intelligent searching,
better RubyGems integration, vastly improved performance, remote queries via
DRb... You can find it at http://eigenclass.org/hiki.rb?fastri and it is also
available in RubyGems format:

    gem install fastri

Read README.emacs and README.vim for information on how to integrate
rcodetools in your editor.

==============================================================================

EOF

  end

  task :gem => [:test]
  Rake::GemPackageTask.new(Spec) do |p|
    p.need_tar_gz = true
  end

rescue LoadError
  # RubyGems not installed
end

desc "install by setup.rb"
task :install do
  sh "sudo ruby setup.rb install"
end

desc "release in rubyforge (package is created)"
task :release_only  do 
  sh "rubyforge login"
  sh "rubyforge add_release rcodetools rcodetools #{RCT_VERSION} pkg/rcodetools-#{RCT_VERSION}.0.tar.gz "
  sh "rubyforge add_file rcodetools rcodetools #{RCT_VERSION} pkg/rcodetools-#{RCT_VERSION}.0.gem "
end

desc "release in rubyforge"
task :release => [:package, :release_only]

# vim: set sw=2 ft=ruby:
