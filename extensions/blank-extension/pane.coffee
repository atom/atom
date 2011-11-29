$ = require 'jquery'
_ = require 'underscore'

fs = require 'fs'

Pane = require 'pane'

module.exports =
class BlankExtension extends Pane
  position: 'left'
  html: null

  constructor: ->
