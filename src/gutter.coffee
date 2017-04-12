{Emitter} = require 'event-kit'
CustomGutterComponent = null

DefaultPriority = -100

# Extended: Represents a gutter within a {TextEditor}.
#
# See {TextEditor::addGutter} for information on creating a gutter.
module.exports =
class Gutter
  constructor: (gutterContainer, options) ->
    @gutterContainer = gutterContainer
    @name = options?.name
    @priority = options?.priority ? DefaultPriority
    @visible = options?.visible ? true

    @emitter = new Emitter

  ###
  Section: Gutter Destruction
  ###

  # Essential: Destroys the gutter.
  destroy: ->
    if @name is 'line-number'
      throw new Error('The line-number gutter cannot be destroyed.')
    else
      @gutterContainer.removeGutter(this)
      @emitter.emit 'did-destroy'
      @emitter.dispose()

  ###
  Section: Event Subscription
  ###

  # Essential: Calls your `callback` when the gutter's visibility changes.
  #
  # * `callback` {Function}
  #  * `gutter` The gutter whose visibility changed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeVisible: (callback) ->
    @emitter.on 'did-change-visible', callback

  # Essential: Calls your `callback` when the gutter is destroyed.
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Visibility
  ###

  # Essential: Hide the gutter.
  hide: ->
    if @visible
      @visible = false
      @gutterContainer.scheduleComponentUpdate()
      @emitter.emit 'did-change-visible', this

  # Essential: Show the gutter.
  show: ->
    if not @visible
      @visible = true
      @gutterContainer.scheduleComponentUpdate()
      @emitter.emit 'did-change-visible', this

  # Essential: Determine whether the gutter is visible.
  #
  # Returns a {Boolean}.
  isVisible: ->
    @visible

  # Essential: Add a decoration that tracks a {DisplayMarker}. When the marker moves,
  # is invalidated, or is destroyed, the decoration will be updated to reflect
  # the marker's state.
  #
  # ## Arguments
  #
  # * `marker` A {DisplayMarker} you want this decoration to follow.
  # * `decorationParams` An {Object} representing the decoration. It is passed
  #   to {TextEditor::decorateMarker} as its `decorationParams` and so supports
  #   all options documented there.
  #   * `type` __Caveat__: set to `'line-number'` if this is the line-number
  #     gutter, `'gutter'` otherwise. This cannot be overridden.
  #
  # Returns a {Decoration} object
  decorateMarker: (marker, options) ->
    @gutterContainer.addGutterDecoration(this, marker, options)

  getElement: ->
    @element ?= document.createElement('div')
