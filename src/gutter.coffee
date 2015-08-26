{Emitter} = require 'event-kit'

DefaultPriority = -100

# Extended: Represents a gutter within a {TextEditor}.
#
# ### Gutter Creation
#
# See {TextEditor::addGutter} for usage.
module.exports =
class Gutter
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
