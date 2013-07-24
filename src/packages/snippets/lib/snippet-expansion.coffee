Subscriber = require 'subscriber'
_ = require 'underscore'

module.exports =
class SnippetExpansion
  snippet: null
  tabStopMarkers: null
  settingTabStop: false

  constructor: (@snippet, @editSession) ->
    @editSession.selectToBeginningOfWord()
    startPosition = @editSession.getCursorBufferPosition()
    @editSession.transact =>
      [newRange] = @editSession.insertText(snippet.body, autoIndent: false)
      if snippet.tabStops.length > 0
        editSession.pushOperation
          do: =>
            @subscribe @editSession, 'cursor-moved.snippet-expansion', (e) => @cursorMoved(e)
            @placeTabStopMarkers(startPosition, snippet.tabStops)
            @editSession.snippetExpansion = this
          undo: => @destroy()
        @editSession.normalizeTabsInBufferRange(newRange)
      @indentSubsequentLines(startPosition.row, snippet) if snippet.lineCount > 1

  cursorMoved: ({oldBufferPosition, newBufferPosition, textChanged}) ->
    return if @settingTabStop or textChanged
    oldTabStops = @tabStopsForBufferPosition(oldBufferPosition)
    newTabStops = @tabStopsForBufferPosition(newBufferPosition)
    @destroy() unless _.intersection(oldTabStops, newTabStops).length

  placeTabStopMarkers: (startPosition, tabStopRanges) ->
    @tabStopMarkers = tabStopRanges.map ({start, end}) =>
      @editSession.markBufferRange([startPosition.add(start), startPosition.add(end)])
    @setTabStopIndex(0)

  indentSubsequentLines: (startRow, snippet) ->
    initialIndent = @editSession.lineForBufferRow(startRow).match(/^\s*/)[0]
    for row in [startRow + 1...startRow + snippet.lineCount]
      @editSession.buffer.insert([row, 0], initialIndent)

  goToNextTabStop: ->
    nextIndex = @tabStopIndex + 1
    if nextIndex < @tabStopMarkers.length
      if @setTabStopIndex(nextIndex)
        true
      else
        @goToNextTabStop()
    else
      @destroy()
      false

  goToPreviousTabStop: ->
    @setTabStopIndex(@tabStopIndex - 1) if @tabStopIndex > 0

  setTabStopIndex: (@tabStopIndex) ->
    @settingTabStop = true
    markerSelected = @editSession.selectMarker(@tabStopMarkers[@tabStopIndex])
    @settingTabStop = false
    markerSelected

  tabStopsForBufferPosition: (bufferPosition) ->
    _.intersection(@tabStopMarkers, @editSession.findMarkers(containsBufferPosition: bufferPosition))

  destroy: ->
    @unsubscribe()
    marker.destroy() for marker in @tabStopMarkers
    @editSession.snippetExpansion = null

  restore: (@editSession) ->
    @editSession.snippetExpansion = this

_.extend(SnippetExpansion.prototype, Subscriber)
