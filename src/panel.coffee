{Emitter} = require 'event-kit'

# Public:
module.exports =
class Panel
  constructor: ({@viewRegistry, @item, @orientation}) ->
    @emitter = new Emitter

  destroy: ->
    @emitter.emit 'did-destroy', this

  getView: -> @viewRegistry.getView(@item)

  getOrientation: -> @orientation

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when the pane is destroyed.
  #
  # * `callback` {Function} to be called when the pane is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback
