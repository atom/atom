{Range} = require 'telepath'
_ = require 'underscore'

### Internal ###

module.exports =
class BufferChangeOperation
  buffer: null
  oldRange: null
  oldText: null
  newRange: null
  newText: null
  markersToRestoreOnUndo: null
  markersToRestoreOnRedo: null

  constructor: ({@buffer, @oldRange, @newText, @options}) ->
    @options ?= {}

  do: ->
    @buffer.pauseEvents()
    @pauseMarkerObservation()
    @markersToRestoreOnUndo = @invalidateMarkers(@oldRange)
    if @oldRange?
      @oldText = @buffer.getTextInRange(@oldRange)
      @newRange = Range.fromText(@oldRange.start, @newText)
      newRange = @changeBuffer
        oldRange: @oldRange
        newRange: @newRange
        oldText: @oldText
        newText: @newText
    @restoreMarkers(@markersToRestoreOnRedo) if @markersToRestoreOnRedo
    @buffer.resumeEvents()
    @resumeMarkerObservation()
    newRange

  undo: ->
    @buffer.pauseEvents()
    @pauseMarkerObservation()
    @markersToRestoreOnRedo = @invalidateMarkers(@newRange)
    if @oldRange?
      @changeBuffer
        oldRange: @newRange
        newRange: @oldRange
        oldText: @newText
        newText: @oldText
    @restoreMarkers(@markersToRestoreOnUndo)
    @buffer.resumeEvents()
    @resumeMarkerObservation()

  changeBuffer: ({ oldRange, newRange, newText, oldText }) ->
    @buffer.text.change(oldRange, newText)

    @buffer.cachedMemoryContents = null
    @buffer.conflict = false if @buffer.conflict and !@buffer.isModified()

    event = { oldRange, newRange, oldText, newText }
    @updateMarkers(event)
    @buffer.trigger 'changed', event
    @buffer.scheduleModifiedEvents()

    newRange

  invalidateMarkers: (oldRange) ->
    @buffer.getMarkers().map (marker) -> marker.tryToInvalidate(oldRange)

  pauseMarkerObservation: ->
    marker.pauseEvents() for marker in @buffer.getMarkers(includeInvalid: true)

  resumeMarkerObservation: ->
    marker.resumeEvents() for marker in @buffer.getMarkers(includeInvalid: true)
    @buffer.trigger 'markers-updated' if @oldRange?

  updateMarkers: (bufferChange) ->
    marker.handleBufferChange(bufferChange) for marker in @buffer.getMarkers()

  restoreMarkers: (markersToRestore) ->
    for [id, previousRange] in markersToRestore
      if validMarker = @buffer.validMarkers[id]
        validMarker.setRange(previousRange)
      else if invalidMarker = @buffer.invalidMarkers[id]
        invalidMarker.revalidate()
