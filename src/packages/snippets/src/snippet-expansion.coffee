Subscriber = require 'subscriber'
_ = require 'underscore'

module.exports =
class SnippetExpansion
  snippet: null
  tabStopAnchorRanges: null
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
            @placeTabStopAnchorRanges(startPosition, snippet.tabStops)
            @editSession.snippetExpansion = this
          undo: => @destroy()
        @editSession.normalizeTabsInBufferRange(newRange)
      @indentSubsequentLines(startPosition.row, snippet) if snippet.lineCount > 1

  cursorMoved: ({oldBufferPosition, newBufferPosition, bufferChanged}) ->
    return if @settingTabStop or bufferChanged
    oldTabStops = @tabStopsForBufferPosition(oldBufferPosition)
    newTabStops = @tabStopsForBufferPosition(newBufferPosition)
    @destroy() unless _.intersect(oldTabStops, newTabStops).length

  placeTabStopAnchorRanges: (startPosition, tabStopRanges) ->
    @tabStopAnchorRanges = tabStopRanges.map ({start, end}) =>
      anchorRange = @editSession.addAnchorRange([startPosition.add(start), startPosition.add(end)])
      @subscribe anchorRange, 'destroyed', =>
        _.remove(@tabStopAnchorRanges, anchorRange)
      anchorRange
    @setTabStopIndex(0)

  indentSubsequentLines: (startRow, snippet) ->
    initialIndent = @editSession.lineForBufferRow(startRow).match(/^\s*/)[0]
    for row in [startRow + 1...startRow + snippet.lineCount]
      @editSession.buffer.insert([row, 0], initialIndent)

  goToNextTabStop: ->
    nextIndex = @tabStopIndex + 1
    if @cursorIsInsideTabStops() and nextIndex < @tabStopAnchorRanges.length
      @setTabStopIndex(nextIndex)
      true
    else
      @destroy()
      false

  goToPreviousTabStop: ->
    if @cursorIsInsideTabStops()
      @setTabStopIndex(@tabStopIndex - 1) if @tabStopIndex > 0
      true
    else
      @destroy()
      false

  ensureValidTabStops: ->
    @tabStopAnchorRanges? and @destroyIfCursorIsOutsideTabStops()

  setTabStopIndex: (@tabStopIndex) ->
    @settingTabStop = true
    @editSession.setSelectedBufferRange(@tabStopAnchorRanges[@tabStopIndex].getBufferRange())
    @settingTabStop = false

  cursorIsInsideTabStops: ->
    position = @editSession.getCursorBufferPosition()
    for anchorRange in @tabStopAnchorRanges
      return true if anchorRange.containsBufferPosition(position)
    false

  tabStopsForBufferPosition: (bufferPosition) ->
    _.intersection(@tabStopAnchorRanges, @editSession.anchorRangesForBufferPosition(bufferPosition))

  destroy: ->
    @unsubscribe()
    anchorRange.destroy() for anchorRange in @tabStopAnchorRanges
    @editSession.snippetExpansion = null

  restore: (@editSession) ->
    @editSession.snippetExpansion = this
    @tabStopAnchorRanges = @tabStopAnchorRanges.map (anchorRange) =>
      @editSession.addAnchorRange(anchorRange.getBufferRange())

_.extend(SnippetExpansion.prototype, Subscriber)
