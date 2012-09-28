set :application, "railsbundle"

require "slicehost/recipes/capistrano"
# Used to setup/update DNS registry of url => ip
set :domain_mapping, "railsbundle.com" => "208.78.99.82"
set :slicehost_config, File.dirname(__FILE__) + "/slicehost.yml"
