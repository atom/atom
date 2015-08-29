{Emitter} = require 'event-kit'

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
      @emitter.emit 'did-change-visible', this

  # Essential: Show the gutter.
  show: ->
    if not @visible
      @visible = true
      @emitter.emit 'did-change-visible', this

  # Essential: Determine whether the gutter is visible.
  #
  # Returns a {Boolean}.
  isVisible: ->
    @visible

  # Essential: Add a decoration that tracks a {Marker}. When the marker moves,
  # is invalidated, or is destroyed, the decoration will be updated to reflect
  # the marker's state.
  #
  # ## Arguments
  #
  # * `marker` A {Marker} you want this decoration to follow.
  # * `decorationParams` An {Object} representing the decoration
  #   * `class` This CSS class will be applied to the decorated line number.
  #   * `onlyHead` (optional) If `true`, the decoration will only be applied to
  #     the head of the marker.
  #   * `onlyEmpty` (optional) If `true`, the decoration will only be applied if
  #     the associated marker is empty.
  #   * `onlyNonEmpty` (optional) If `true`, the decoration will only be applied
  #     if the associated marker is non-empty.
  #
  # Returns a {Decoration} object
  decorateMarker: (marker, options) ->
    @gutterContainer.addGutterDecoration(this, marker, options)
