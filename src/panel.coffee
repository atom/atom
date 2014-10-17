{Emitter} = require 'event-kit'

# Public:
module.exports =
class Panel
  constructor: ({@viewRegistry, @item, @visible, @priority}) ->
    @emitter = new Emitter
    @visible ?= true
    @priority ?= 100

  destroy: ->
    @emitter.emit 'did-destroy', this

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

  onDidChangeVisible: (callback) ->
    @emitter.on 'did-change-visible', callback

  ###
  Section: Panel Details
  ###

  getView: -> @viewRegistry.getView(this)

  getItemView: -> @viewRegistry.getView(@item)

  getPriority: -> @priority

  isVisible: -> @visible

  hide: ->
    wasVisible = @visible
    @visible = false
    @emitter.emit 'did-change-visible', @visible if wasVisible

  show: ->
    wasVisible = @visible
    @visible = true
    @emitter.emit 'did-change-visible', @visible unless wasVisible
