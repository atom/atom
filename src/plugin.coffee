module.exports =
class Plugin
  constructor: (@window) ->
    console.log "Loaded Plugin: " + @.constructor.name

  # Called after the window is fully loaded
  initialize: ->

  # Called when @window is closed
  destroy: ->

