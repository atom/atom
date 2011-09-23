$ = require 'jquery'
_ = require 'underscore'

Pane = require 'pane'
File = require 'fs'
Plugin = require 'plugin'

{CoffeeScript} = require 'coffee-script'

module.exports =
class TinyTest extends Plugin
  keymap: ->
    'Command-Ctrl-T': 'runTests'

  runTests: ->
    _.map File.list(@window.path + '/test'), @runTest

  runTest: (path) ->
    # Even though we already have the path, run it
    # through resolve() so we might find the dev version.
    path = require.resolve _.last path.split '/'
    name = _.last path.split '/'

    try
      if /\.coffee$/.test path
        eval CoffeeScript.compile File.read path
      else
        eval File.read path
      console.log "all tests passed in #{name}"
    catch e
      if e.actual? and e.expected?
        console.error "#{e.operator} test failed in #{name}:"
        console.error e.actual
        console.error "isn't"
        console.error e.expected
      else
        throw e
