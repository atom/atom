_ = require 'underscore-plus'
{Subscriber, Emitter} = require 'emissary'

idCounter = 0
nextId = -> idCounter++

# Public: Represents a decoration that follows a {Marker}. A decoration is
# basically a visual representation of a marker. It allows you to add CSS
# classes to line numbers in the gutter, lines, and add selection-line regions
# around marked ranges of text.
#
# {Decoration} objects are not meant to be created directly, but created with
# {Editor::decorateMarker}. eg.
#
# ```coffee
# range = editor.getSelectedBufferRange() # any range you like
# marker = editor.markBufferRange(range)
# decoration = editor.decorateMarker(marker, {type: 'line', class: 'my-line-class'})
# ```
#
# Best practice for destorying the decoration is by destroying the {Marker}.
#
# ```
# marker.destroy()
# ```
#
# You should only use {Decoration::destroy} when you still need or do not own
# the marker.
#
# ### IDs
# Each {Decoration} has a unique ID available via `decoration.id`.
#
# ### Events
# A couple of events are emitted:
#
# * `destroyed`: When the {Decoration} is destroyed
# * `updated`: When the {Decoration} is updated via {Decoration::update}.
#     Event object has properties `oldParams` and `newParams`
#
module.exports =
class Decoration
  Emitter.includeInto(this)

  @isType: (decorationParams, type) ->
    if _.isArray(decorationParams.type)
      type in decorationParams.type
    else
      type is decorationParams.type

  constructor: (@marker, @displayBuffer, @params) ->
    @id = nextId()
    @params.id = @id
    @flashQueue = null
    @isDestroyed = false

  # Public: Destroy this marker.
  #
  # If you own the marker, you should use {Marker::destroy} which will destroy
  # this decoration.
  destroy: ->
    return if @isDestroyed
    @isDestroyed = true
    @displayBuffer.removeDecoration(this)
    @emit 'destoryed'

  # Public: Update the marker with new params. Allows you to change the decoration's class.
  #
  # ```
  # decoration.update({type: 'gutter', class: 'my-new-class'})
  # ```
  update: (newParams) ->
    return if @isDestroyed
    oldParams = @params
    @params = newParams
    @params.id = @id
    @displayBuffer.decorationUpdated(this)
    @emit 'updated', {oldParams, newParams}

  # Public: Returns the marker associated with this {Decoration}
  getMarker: -> @marker

  # Public: Returns the {Decoration}'s params.
  getParams: -> @params

  # Public: Check if this decoration is of type `type`
  #
  # type - A {String} type like `'gutter'`
  #
  # Returns a {Boolean}
  isType: (type) ->
    Decoration.isType(@params, type)

  matchesPattern: (decorationPattern) ->
    return false unless decorationPattern?
    for key, value of decorationPattern
      return false if @params[key] != value
    true

  flash: (klass, duration=500) ->
    flashObject = {class: klass, duration}
    @flashQueue ?= []
    @flashQueue.push(flashObject)
    @emit 'flash'

  consumeNextFlash: ->
    return @flashQueue.shift() if @flashQueue?.length > 0
    null
