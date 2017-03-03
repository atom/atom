_ = require 'underscore-plus'
{Emitter} = require 'event-kit'

idCounter = 0
nextId = -> idCounter++

# Applies changes to a decorationsParam {Object} to make it possible to
# differentiate decorations on custom gutters versus the line-number gutter.
translateDecorationParamsOldToNew = (decorationParams) ->
  if decorationParams.type is 'line-number'
    decorationParams.gutterName = 'line-number'
  decorationParams

# Essential: Represents a decoration that follows a {DisplayMarker}. A decoration is
# basically a visual representation of a marker. It allows you to add CSS
# classes to line numbers in the gutter, lines, and add selection-line regions
# around marked ranges of text.
#
# {Decoration} objects are not meant to be created directly, but created with
# {TextEditor::decorateMarker}. eg.
#
# ```coffee
# range = editor.getSelectedBufferRange() # any range you like
# marker = editor.markBufferRange(range)
# decoration = editor.decorateMarker(marker, {type: 'line', class: 'my-line-class'})
# ```
#
# Best practice for destroying the decoration is by destroying the {DisplayMarker}.
#
# ```coffee
# marker.destroy()
# ```
#
# You should only use {Decoration::destroy} when you still need or do not own
# the marker.
module.exports =
class Decoration
  # Private: Check if the `decorationProperties.type` matches `type`
  #
  # * `decorationProperties` {Object} eg. `{type: 'line-number', class: 'my-new-class'}`
  # * `type` {String} type like `'line-number'`, `'line'`, etc. `type` can also
  #   be an {Array} of {String}s, where it will return true if the decoration's
  #   type matches any in the array.
  #
  # Returns {Boolean}
  # Note: 'line-number' is a special subtype of the 'gutter' type. I.e., a
  # 'line-number' is a 'gutter', but a 'gutter' is not a 'line-number'.
  @isType: (decorationProperties, type) ->
    # 'line-number' is a special case of 'gutter'.
    if _.isArray(decorationProperties.type)
      return true if type in decorationProperties.type
      if type is 'gutter'
        return true if 'line-number' in decorationProperties.type
      return false
    else
      if type is 'gutter'
        return true if decorationProperties.type in ['gutter', 'line-number']
      else
        type is decorationProperties.type

  ###
  Section: Construction and Destruction
  ###

  constructor: (@marker, @decorationManager, properties) ->
    @emitter = new Emitter
    @id = nextId()
    @setProperties properties
    @destroyed = false
    @markerDestroyDisposable = @marker.onDidDestroy => @destroy()

  # Essential: Destroy this marker decoration.
  #
  # You can also destroy the marker if you own it, which will destroy this
  # decoration.
  destroy: ->
    return if @destroyed
    @markerDestroyDisposable.dispose()
    @markerDestroyDisposable = null
    @destroyed = true
    @decorationManager.didDestroyMarkerDecoration(this)
    @emitter.emit 'did-destroy'
    @emitter.dispose()

  isDestroyed: -> @destroyed

  ###
  Section: Event Subscription
  ###

  # Essential: When the {Decoration} is updated via {Decoration::update}.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `oldProperties` {Object} the old parameters the decoration used to have
  #     * `newProperties` {Object} the new parameters the decoration now has
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeProperties: (callback) ->
    @emitter.on 'did-change-properties', callback

  # Essential: Invoke the given callback when the {Decoration} is destroyed
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Decoration Details
  ###

  # Essential: An id unique across all {Decoration} objects
  getId: -> @id

  # Essential: Returns the marker associated with this {Decoration}
  getMarker: -> @marker

  # Public: Check if this decoration is of type `type`
  #
  # * `type` {String} type like `'line-number'`, `'line'`, etc. `type` can also
  #   be an {Array} of {String}s, where it will return true if the decoration's
  #   type matches any in the array.
  #
  # Returns {Boolean}
  isType: (type) ->
    Decoration.isType(@properties, type)

  ###
  Section: Properties
  ###

  # Essential: Returns the {Decoration}'s properties.
  getProperties: ->
    @properties

  # Essential: Update the marker with new Properties. Allows you to change the decoration's class.
  #
  # ## Examples
  #
  # ```coffee
  # decoration.update({type: 'line-number', class: 'my-new-class'})
  # ```
  #
  # * `newProperties` {Object} eg. `{type: 'line-number', class: 'my-new-class'}`
  setProperties: (newProperties) ->
    return if @destroyed
    oldProperties = @properties
    @properties = translateDecorationParamsOldToNew(newProperties)
    if newProperties.type?
      @decorationManager.decorationDidChangeType(this)
    @decorationManager.emitDidUpdateDecorations()
    @emitter.emit 'did-change-properties', {oldProperties, newProperties}

  ###
  Section: Utility
  ###

  inspect: ->
    "<Decoration #{@id}>"

  ###
  Section: Private methods
  ###

  matchesPattern: (decorationPattern) ->
    return false unless decorationPattern?
    for key, value of decorationPattern
      return false if @properties[key] isnt value
    true

  flash: (klass, duration=500) ->
    @properties.flashCount ?= 0
    @properties.flashCount++
    @properties.flashClass = klass
    @properties.flashDuration = duration
    @decorationManager.emitDidUpdateDecorations()
    @emitter.emit 'did-flash'
