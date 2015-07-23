{Emitter} = require 'event-kit'

# Public: This class represents a gutter within a TextEditor.

DefaultPriority = -100

module.exports =
class Gutter
  # * `gutterContainer` The {GutterContainer} object to which this gutter belongs.
  # * `options` An {Object} with the following fields:
  #   * `name` (required) A unique {String} to identify this gutter.
  #   * `priority` (optional) A {Number} that determines stacking order between
  #       gutters. Lower priority items are forced closer to the edges of the
  #       window. (default: -100)
  #   * `visible` (optional) {Boolean} specifying whether the gutter is visible
  #       initially after being created. (default: true)
  constructor: (gutterContainer, options) ->
    @gutterContainer = gutterContainer
    @name = options?.name
    @priority = options?.priority ? DefaultPriority
    @visible = options?.visible ? true

    @emitter = new Emitter

  destroy: ->
    if @name is 'line-number'
      throw new Error('The line-number gutter cannot be destroyed.')
    else
      @gutterContainer.removeGutter(this)
      @emitter.emit 'did-destroy'
      @emitter.dispose()

  hide: ->
    if @visible
      @visible = false
      @emitter.emit 'did-change-visible', this

  show: ->
    if not @visible
      @visible = true
      @emitter.emit 'did-change-visible', this

  isVisible: ->
    @visible

  # * `marker` (required) A Marker object.
  # * `options` (optional) An object with the following fields:
  #   * `class` (optional)
  #   * `item` (optional) A model {Object} with a corresponding view registered,
  #     or an {HTMLElement}.
  #
  # Returns a {Decoration} object.
  decorateMarker: (marker, options) ->
    @gutterContainer.addGutterDecoration(this, marker, options)

  # Calls your `callback` when the {Gutter}'s' visibility changes.
  #
  # * `callback` {Function}
  #  * `gutter` The {Gutter} whose visibility changed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeVisible: (callback) ->
    @emitter.on 'did-change-visible', callback

  # Calls your `callback` when the {Gutter} is destroyed
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback
