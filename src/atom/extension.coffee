# Extension subclasses must call super in all overridden methods.
module.exports =
class Extension
  running: false

  constructor: ->
    console.log "#{@constructor.name}: Running"

  # `startup` should be called by you in Extension subclasses when they need
  # to appear on the screen, attach themselves to a Resource, or otherwise become active.
  startup: ->
    @running = true

  # `shutdown` shuold be called by you in Extension subclasses when they need
  # to be remove from the screen, unattach themselves from a Resource, or otherwise become
  # inactive.
  shutdown: ->
    @running = false