{Emitter} = require 'event-kit'
PanelElement = require './panel-element'

# Extended: A container representing a panel on the edges of the editor window.
# You should not create a `Panel` directly, instead use {Workspace::addTopPanel}
# and friends to add panels.
#
# Examples: [status-bar](https://github.com/atom/status-bar)
# and [find-and-replace](https://github.com/atom/find-and-replace) both use
# panels.
module.exports =
class Panel
  ###
  Section: Construction and Destruction
  ###

  constructor: ({@item, @visible, @priority, @className}, @viewRegistry) ->
    @emitter = new Emitter
    @visible ?= true
    @priority ?= 100

  # Public: Destroy and remove this panel from the UI.
  destroy: ->
    @hide()
    @emitter.emit 'did-destroy', this
    @emitter.dispose()

  getElement: ->
    unless @element
      @element = new PanelElement().initialize(this, @viewRegistry)
    @element

  ###
  Section: Event Subscription
  ###

  # Public: Invoke the given callback when the pane hidden or shown.
  #
  # * `callback` {Function} to be called when the pane is destroyed.
  #   * `visible` {Boolean} true when the panel has been shown
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeVisible: (callback) ->
    @emitter.on 'did-change-visible', callback

  # Public: Invoke the given callback when the pane is destroyed.
  #
  # * `callback` {Function} to be called when the pane is destroyed.
  #   * `panel` {Panel} this panel
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Panel Details
  ###

  # Public: Returns the panel's item.
  getItem: -> @item

  # Public: Returns a {Number} indicating this panel's priority.
  getPriority: -> @priority

  getClassName: -> @className

  # Public: Returns a {Boolean} true when the panel is visible.
  isVisible: -> @visible

  # Public: Hide this panel
  hide: ->
    wasVisible = @visible
    @visible = false
    @emitter.emit 'did-change-visible', @visible if wasVisible

  # Public: Show this panel
  show: ->
    wasVisible = @visible
    @visible = true
    @emitter.emit 'did-change-visible', @visible unless wasVisible
