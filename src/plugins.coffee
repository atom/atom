$ = require 'jquery'
_ = require 'underscore'

File = require 'fs'
App  = require 'app'

_.map File.list(App.root + "/plugins"), (plugin) ->
  require plugin

_.map File.list("~/.atomicity/"), (path) ->
  require path
