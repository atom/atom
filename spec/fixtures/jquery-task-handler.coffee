module.exports =
  load: ->
    $ = require 'jquery'
    callTaskMethod('loaded', $?)
