_ = require 'underscore-plus'
{Subscriber, Emitter} = require 'emissary'

idCounter = 0
nextId = -> idCounter++

# Essential: Represents a decoration that follows a {Marker}. A decoration is
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
# ```coffee
# marker.destroy()
# ```
#
# You should only use {Decoration::destroy} when you still need or do not own
# the marker.
#
# ## Events
#
# A couple of events are emitted:
#
# * `destroyed`: When the {Decoration} is destroyed
# * `updated`: When the {Decoration} is updated via {Decoration::update}.
#     Event object has properties `oldParams` and `newParams`
#
module.exports =
class Decoration
  Emitter.includeInto(this)

  # Extended: Check if the `decorationParams.type` matches `type`
  #
  # * `decorationParams` {Object} eg. `{type: 'gutter', class: 'my-new-class'}`
  # * `type` {String} type like `'gutter'`, `'line'`, etc. `type` can also
  #          be an {Array} of {String}s, where it will return
  #          true if the decoration's type matches any in the array.
  #
  # Returns {Boolean}
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

  # Essential: An id unique across all {Decoration} objects
  getId: -> @id

  # Essential: Returns the marker associated with this {Decoration}
  getMarker: -> @marker

  # Essential: Returns the {Decoration}'s params.
  getParams: -> @params

  # Public: Check if this decoration is of type `type`
  #
  # * `type` {String} type like `'gutter'`, `'line'`, etc. `type` can also
  #          be an {Array} of {String}s, where it will return
  #          true if the decoration's type matches any in the array.
  #
  # Returns {Boolean}
  isType: (type) ->
    Decoration.isType(@params, type)

  # Essential: Update the marker with new params. Allows you to change the decoration's class.
  #
  # ## Examples
  #
  # ```coffee
  # decoration.update({type: 'gutter', class: 'my-new-class'})
  # ```
  #
  # * `newParams` {Object} eg. `{type: 'gutter', class: 'my-new-class'}`
  update: (newParams) ->
    return if @isDestroyed
    oldParams = @params
    @params = newParams
    @params.id = @id
    @displayBuffer.decorationUpdated(this)
    @emit 'updated', {oldParams, newParams}

  # Essential: Destroy this marker.
  #
  # If you own the marker, you should use {Marker::destroy} which will destroy
  # this decoration.
  destroy: ->
    return if @isDestroyed
    @isDestroyed = true
    @displayBuffer.removeDecoration(this)
    @emit 'destroyed'

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
