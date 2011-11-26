$ = require 'jquery'
_ = require 'underscore'
fs = require 'fs'

Pane = require 'pane'
Extension = require 'extension'

{CoffeeScript} = require 'coffee-script'

module.exports =
class TinyTest extends Extension
  run: ->
    _.map fs.list(window.url + '/test'), @runTest

  runTest: (path) ->
    name = _.last path.split '/'

    try
      delete require.__modules[path] if require.__modules[path]
      require path
      console.log "all tests passed in #{name}"
    catch e
      if e.actual? and e.expected?
        console.error "#{e.operator} test failed in #{name}:"
        console.error e.actual
        console.error "isn't"
        console.error e.expected
      else
        throw e
