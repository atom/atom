require 'rubygems'
require 'rake'
require 'rake/testtask'

APP_VERSION="2.0.0"
APP_NAME='Ruby on Rails.tmbundle'
APP_ROOT=File.dirname(__FILE__)

RUBY_APP='ruby'

desc "TMBundle Test Task"
task :default => [ :test ]
Rake::TestTask.new { |t|
  t.libs << "test"
  t.pattern = 'Support/test/*_test.rb'
  t.verbose = true
  t.warning = false
}
Dir['tasks/**/*.rake'].each { |file| load file }
