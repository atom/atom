_ = require 'underscore-plus'
{CompositeDisposable, Emitter} = require 'event-kit'

# Essential: Represents a buffer annotation that remains logically stationary
# even as the buffer changes. This is used to represent cursors, folds, snippet
# targets, misspelled words, and anything else that needs to track a logical
# location in the buffer over time.
#
# ### Marker Creation
#
# Use {TextEditor::markBufferRange} rather than creating Markers directly.
#
# ### Head and Tail
#
# Markers always have a *head* and sometimes have a *tail*. If you think of a
# marker as an editor selection, the tail is the part that's stationary and the
# head is the part that moves when the mouse is moved. A marker without a tail
# always reports an empty range at the head position. A marker with a head position
# greater than the tail is in a "normal" orientation. If the head precedes the
# tail the marker is in a "reversed" orientation.
#
# ### Validity
#
# Markers are considered *valid* when they are first created. Depending on the
# invalidation strategy you choose, certain changes to the buffer can cause a
# marker to become invalid, for example if the text surrounding the marker is
# deleted. The strategies, in order of descending fragility:
#
# * __never__: The marker is never marked as invalid. This is a good choice for
#   markers representing selections in an editor.
# * __surround__: The marker is invalidated by changes that completely surround it.
# * __overlap__: The marker is invalidated by changes that surround the
#   start or end of the marker. This is the default.
# * __inside__: The marker is invalidated by changes that extend into the
#   inside of the marker. Changes that end at the marker's start or
#   start at the marker's end do not invalidate the marker.
# * __touch__: The marker is invalidated by a change that touches the marked
#   region in any way, including changes that end at the marker's
#   start or start at the marker's end. This is the most fragile strategy.
#
# See {TextEditor::markBufferRange} for usage.
module.exports =
class Marker
  bufferMarkerSubscription: null
  oldHeadBufferPosition: null
  oldHeadScreenPosition: null
  oldTailBufferPosition: null
  oldTailScreenPosition: null
  wasValid: true
  hasChangeObservers: false

  ###
  Section: Construction and Destruction
  ###

  constructor: ({@bufferMarker, @displayBuffer}) ->
    @emitter = new Emitter
    @disposables = new CompositeDisposable
    @id = @bufferMarker.id

    @disposables.add @bufferMarker.onDidDestroy => @destroyed()

  # Essential: Destroys the marker, causing it to emit the 'destroyed' event. Once
  # destroyed, a marker cannot be restored by undo/redo operations.
  destroy: ->
    @bufferMarker.destroy()
    @disposables.dispose()

  # Essential: Creates and returns a new {Marker} with the same properties as
  # this marker.
  #
  # {Selection} markers (markers with a custom property `type: "selection"`)
  # should be copied with a different `type` value, for example with
  # `marker.copy({type: null})`. Otherwise, the new marker's selection will
  # be merged with this marker's selection, and a `null` value will be
  # returned.
  #
  # * `properties` (optional) {Object} properties to associate with the new
  # marker. The new marker's properties are computed by extending this marker's
  # properties with `properties`.
  #
  # Returns a {Marker}.
  copy: (properties) ->
    @displayBuffer.getMarker(@bufferMarker.copy(properties).id)

  ###
  Section: Event Subscription
  ###

  # Essential: Invoke the given callback when the state of the marker changes.
  #
  # * `callback` {Function} to be called when the marker changes.
  #   * `event` {Object} with the following keys:
  #     * `oldHeadBufferPosition` {Point} representing the former head buffer position
  #     * `newHeadBufferPosition` {Point} representing the new head buffer position
  #     * `oldTailBufferPosition` {Point} representing the former tail buffer position
  #     * `newTailBufferPosition` {Point} representing the new tail buffer position
  #     * `oldHeadScreenPosition` {Point} representing the former head screen position
  #     * `newHeadScreenPosition` {Point} representing the new head screen position
  #     * `oldTailScreenPosition` {Point} representing the former tail screen position
  #     * `newTailScreenPosition` {Point} representing the new tail screen position
  #     * `wasValid` {Boolean} indicating whether the marker was valid before the change
  #     * `isValid` {Boolean} indicating whether the marker is now valid
  #     * `hadTail` {Boolean} indicating whether the marker had a tail before the change
  #     * `hasTail` {Boolean} indicating whether the marker now has a tail
  #     * `oldProperties` {Object} containing the marker's custom properties before the change.
  #     * `newProperties` {Object} containing the marker's custom properties after the change.
  #     * `textChanged` {Boolean} indicating whether this change was caused by a textual change
  #       to the buffer or whether the marker was manipulated directly via its public API.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChange: (callback) ->
    unless @hasChangeObservers
      @oldHeadBufferPosition = @getHeadBufferPosition()
      @oldHeadScreenPosition = @getHeadScreenPosition()
      @oldTailBufferPosition = @getTailBufferPosition()
      @oldTailScreenPosition = @getTailScreenPosition()
      @wasValid = @isValid()
      @disposables.add @bufferMarker.onDidChange (event) => @notifyObservers(event)
      @hasChangeObservers = true
    @emitter.on 'did-change', callback

  # Essential: Invoke the given callback when the marker is destroyed.
  #
  # * `callback` {Function} to be called when the marker is destroyed.
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Marker Details
  ###

  # Essential: Returns a {Boolean} indicating whether the marker is valid. Markers can be
  # invalidated when a region surrounding them in the buffer is changed.
  isValid: ->
    @bufferMarker.isValid()

  # Essential: Returns a {Boolean} indicating whether the marker has been destroyed. A marker
  # can be invalid without being destroyed, in which case undoing the invalidating
  # operation would restore the marker. Once a marker is destroyed by calling
  # {Marker::destroy}, no undo/redo operation can ever bring it back.
  isDestroyed: ->
    @bufferMarker.isDestroyed()

  # Essential: Returns a {Boolean} indicating whether the head precedes the tail.
  isReversed: ->
    @bufferMarker.isReversed()

  # Essential: Get the invalidation strategy for this marker.
  #
  # Valid values include: `never`, `surround`, `overlap`, `inside`, and `touch`.
  #
  # Returns a {String}.
  getInvalidationStrategy: ->
    @bufferMarker.getInvalidationStrategy()

  # Essential: Returns an {Object} containing any custom properties associated with
  # the marker.
  getProperties: ->
    @bufferMarker.getProperties()

  # Essential: Merges an {Object} containing new properties into the marker's
  # existing properties.
  #
  # * `properties` {Object}
  setProperties: (properties) ->
    @bufferMarker.setProperties(properties)

  matchesProperties: (attributes) ->
    attributes = @displayBuffer.translateToBufferMarkerParams(attributes)
    @bufferMarker.matchesParams(attributes)

  ###
  Section: Comparing to other markers
  ###

  # Essential: Returns a {Boolean} indicating whether this marker is equivalent to
  # another marker, meaning they have the same range and options.
  #
  # * `other` {Marker} other marker
  isEqual: (other) ->
    return false unless other instanceof @constructor
    @bufferMarker.isEqual(other.bufferMarker)

  # Essential: Compares this marker to another based on their ranges.
  #
  # * `other` {Marker}
  #
  # Returns a {Number}
  compare: (other) ->
    @bufferMarker.compare(other.bufferMarker)

  ###
  Section: Managing the marker's range
  ###

  # Essential: Gets the buffer range of the display marker.
  #
  # Returns a {Range}.
  getBufferRange: ->
    @bufferMarker.getRange()

  # Essential: Modifies the buffer range of the display marker.
  #
  # * `bufferRange` The new {Range} to use
  # * `properties` (optional) {Object} properties to associate with the marker.
  #   * `reversed` {Boolean} If true, the marker will to be in a reversed orientation.
  setBufferRange: (bufferRange, properties) ->
    @bufferMarker.setRange(bufferRange, properties)

  # Essential: Gets the screen range of the display marker.
  #
  # Returns a {Range}.
  getScreenRange: ->
    @displayBuffer.screenRangeForBufferRange(@getBufferRange(), wrapAtSoftNewlines: true)

  # Essential: Modifies the screen range of the display marker.
  #
  # * `screenRange` The new {Range} to use
  # * `properties` (optional) {Object} properties to associate with the marker.
  #   * `reversed` {Boolean} If true, the marker will to be in a reversed orientation.
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@displayBuffer.bufferRangeForScreenRange(screenRange), options)

  # Essential: Retrieves the buffer position of the marker's start. This will always be
  # less than or equal to the result of {Marker::getEndBufferPosition}.
  #
  # Returns a {Point}.
  getStartBufferPosition: ->
    @bufferMarker.getStartPosition()

  # Essential: Retrieves the screen position of the marker's start. This will always be
  # less than or equal to the result of {Marker::getEndScreenPosition}.
  #
  # Returns a {Point}.
  getStartScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getStartBufferPosition(), wrapAtSoftNewlines: true)

  # Essential: Retrieves the buffer position of the marker's end. This will always be
  # greater than or equal to the result of {Marker::getStartBufferPosition}.
  #
  # Returns a {Point}.
  getEndBufferPosition: ->
    @bufferMarker.getEndPosition()

  # Essential: Retrieves the screen position of the marker's end. This will always be
  # greater than or equal to the result of {Marker::getStartScreenPosition}.
  #
  # Returns a {Point}.
  getEndScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getEndBufferPosition(), wrapAtSoftNewlines: true)

  # Extended: Retrieves the buffer position of the marker's head.
  #
  # Returns a {Point}.
  getHeadBufferPosition: ->
    @bufferMarker.getHeadPosition()

  # Extended: Sets the buffer position of the marker's head.
  #
  # * `bufferPosition` The new {Point} to use
  # * `properties` (optional) {Object} properties to associate with the marker.
  setHeadBufferPosition: (bufferPosition, properties) ->
    @bufferMarker.setHeadPosition(bufferPosition, properties)

  # Extended: Retrieves the screen position of the marker's head.
  #
  # Returns a {Point}.
  getHeadScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getHeadBufferPosition(), wrapAtSoftNewlines: true)

  # Extended: Sets the screen position of the marker's head.
  #
  # * `screenPosition` The new {Point} to use
  # * `properties` (optional) {Object} properties to associate with the marker.
  setHeadScreenPosition: (screenPosition, properties) ->
    @setHeadBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, properties))

  # Extended: Retrieves the buffer position of the marker's tail.
  #
  # Returns a {Point}.
  getTailBufferPosition: ->
    @bufferMarker.getTailPosition()

  # Extended: Sets the buffer position of the marker's tail.
  #
  # * `bufferPosition` The new {Point} to use
  # * `properties` (optional) {Object} properties to associate with the marker.
  setTailBufferPosition: (bufferPosition) ->
    @bufferMarker.setTailPosition(bufferPosition)

  # Extended: Retrieves the screen position of the marker's tail.
  #
  # Returns a {Point}.
  getTailScreenPosition: ->
    @displayBuffer.screenPositionForBufferPosition(@getTailBufferPosition(), wrapAtSoftNewlines: true)

  # Extended: Sets the screen position of the marker's tail.
  #
  # * `screenPosition` The new {Point} to use
  # * `properties` (optional) {Object} properties to associate with the marker.
  setTailScreenPosition: (screenPosition, options) ->
    @setTailBufferPosition(@displayBuffer.bufferPositionForScreenPosition(screenPosition, options))

  # Extended: Returns a {Boolean} indicating whether the marker has a tail.
  hasTail: ->
    @bufferMarker.hasTail()

  # Extended: Plants the marker's tail at the current head position. After calling
  # the marker's tail position will be its head position at the time of the
  # call, regardless of where the marker's head is moved.
  #
  # * `properties` (optional) {Object} properties to associate with the marker.
  plantTail: ->
    @bufferMarker.plantTail()

  # Extended: Removes the marker's tail. After calling the marker's head position
  # will be reported as its current tail position until the tail is planted
  # again.
  #
  # * `properties` (optional) {Object} properties to associate with the marker.
  clearTail: (properties) ->
    @bufferMarker.clearTail(properties)

  ###
  Section: Private utility methods
  ###

  # Returns a {String} representation of the marker
  inspect: ->
    "Marker(id: #{@id}, bufferRange: #{@getBufferRange()})"

  destroyed: ->
    delete @displayBuffer.markers[@id]
    @emitter.emit 'did-destroy'
    @emitter.dispose()

  notifyObservers: ({textChanged}) ->
    textChanged ?= false

    newHeadBufferPosition = @getHeadBufferPosition()
    newHeadScreenPosition = @getHeadScreenPosition()
    newTailBufferPosition = @getTailBufferPosition()
    newTailScreenPosition = @getTailScreenPosition()
    isValid = @isValid()

    return if isValid is @wasValid and
      newHeadBufferPosition.isEqual(@oldHeadBufferPosition) and
      newHeadScreenPosition.isEqual(@oldHeadScreenPosition) and
      newTailBufferPosition.isEqual(@oldTailBufferPosition) and
      newTailScreenPosition.isEqual(@oldTailScreenPosition)

    changeEvent = {
      @oldHeadScreenPosition, newHeadScreenPosition,
      @oldTailScreenPosition, newTailScreenPosition,
      @oldHeadBufferPosition, newHeadBufferPosition,
      @oldTailBufferPosition, newTailBufferPosition,
      textChanged,
      isValid
    }

    @oldHeadBufferPosition = newHeadBufferPosition
    @oldHeadScreenPosition = newHeadScreenPosition
    @oldTailBufferPosition = newTailBufferPosition
    @oldTailScreenPosition = newTailScreenPosition
    @wasValid = isValid

    @emitter.emit 'did-change', changeEvent
