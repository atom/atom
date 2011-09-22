{bindKey} = require 'keybinder'

module.exports =
class Pane
  position: null

  html: null

  showing: false

  constructor: (@window) ->

  toggle: ->
    if @showing
      @html.parent().detach()
    else
      @window.addPane this

    @showing = not @showing

  # Override these in your subclass
  initialize: ->
