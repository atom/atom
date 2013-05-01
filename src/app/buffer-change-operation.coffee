Range = require 'range'
_ = require 'underscore'

###
# Internal #
###

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
    @oldText = @buffer.getTextInRange(@oldRange)
    @newRange = @calculateNewRange(@oldRange, @newText)
    @markersToRestoreOnUndo = @invalidateMarkers(@oldRange)
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
    @changeBuffer
      oldRange: @newRange
      newRange: @oldRange
      oldText: @newText
      newText: @oldText
    @restoreMarkers(@markersToRestoreOnUndo)
    @buffer.resumeEvents()
    @resumeMarkerObservation()

  splitLines: (text) ->
    lines = text.split('\n')
    lineEndings = []
    for line, index in lines
      if _.endsWith(line, '\r')
        lines[index] = line[...-1]
        lineEndings[index] = '\r\n'
      else
        lineEndings[index] = '\n'
    {lines, lineEndings}

  changeBuffer: ({ oldRange, newRange, newText, oldText }) ->
    { prefix, suffix } = @buffer.prefixAndSuffixForRange(oldRange)
    {lines, lineEndings} = @splitLines(newText)
    lastLineIndex = lines.length - 1

    if lines.length == 1
      lines = [prefix + newText + suffix]
    else
      lines[0] = prefix + lines[0]
      lines[lastLineIndex] += suffix

    startRow = oldRange.start.row
    endRow = oldRange.end.row

    normalizeLineEndings = @options.normalizeLineEndings ? true
    if normalizeLineEndings and suggestedLineEnding = @buffer.suggestedLineEndingForRow(startRow)
      lineEndings[index] = suggestedLineEnding for index in [0..lastLineIndex]

    _.spliceWithArray(@buffer.lines, startRow, endRow - startRow + 1, lines)
    _.spliceWithArray(@buffer.lineEndings, startRow, endRow - startRow + 1, lineEndings)
    @buffer.cachedMemoryContents = null
    @buffer.conflict = false if @buffer.conflict and !@buffer.isModified()

    event = { oldRange, newRange, oldText, newText }
    @updateMarkers(event)
    @buffer.trigger 'changed', event
    @buffer.scheduleModifiedEvents()

    newRange

  calculateNewRange: (oldRange, newText) ->
    newRange = new Range(oldRange.start.copy(), oldRange.start.copy())
    {lines} = @splitLines(newText)
    if lines.length == 1
      newRange.end.column += newText.length
    else
      lastLineIndex = lines.length - 1
      newRange.end.row += lastLineIndex
      newRange.end.column = lines[lastLineIndex].length
    newRange

  invalidateMarkers: (oldRange) ->
    @buffer.getMarkers().map (marker) -> marker.tryToInvalidate(oldRange)

  pauseMarkerObservation: ->
    marker.pauseEvents() for marker in @buffer.getMarkers(includeInvalid: true)

  resumeMarkerObservation: ->
    marker.resumeEvents() for marker in @buffer.getMarkers(includeInvalid: true)
    @buffer.trigger 'markers-updated'

  updateMarkers: (bufferChange) ->
    marker.handleBufferChange(bufferChange) for marker in @buffer.getMarkers()

  restoreMarkers: (markersToRestore) ->
    for [id, previousRange] in markersToRestore
      if validMarker = @buffer.validMarkers[id]
        validMarker.setRange(previousRange)
      else if invalidMarker = @buffer.invalidMarkers[id]
        invalidMarker.revalidate()
