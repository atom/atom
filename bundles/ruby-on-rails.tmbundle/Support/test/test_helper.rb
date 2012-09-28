require 'test/unit'
require "fileutils"
$:.push File.dirname(__FILE__)
$:.push File.dirname(__FILE__) + '/../lib'
FIXTURE_PATH = File.expand_path(File.dirname(__FILE__) + '/app_fixtures')

def ruby(command)
  `/usr/bin/env ruby #{command}`
end
