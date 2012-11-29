_ = require 'underscore'

module.exports =
class SnippetExpansion
  tabStopAnchorRanges: null
  settingTabStop: false

  constructor: (snippet, @editSession) ->
    @editSession.selectToBeginningOfWord()
    startPosition = @editSession.getCursorBufferPosition()
    @editSession.transact =>
      @editSession.insertText(snippet.body, autoIndent: false)
      if snippet.tabStops.length
        @placeTabStopAnchorRanges(startPosition, snippet.tabStops)
      if snippet.lineCount > 1
        @indentSubsequentLines(startPosition.row, snippet)

    @editSession.on 'cursor-moved.snippet-expansion', ({oldBufferPosition, newBufferPosition}) =>
      return if @settingTabStop

      oldTabStops = @tabStopsForBufferPosition(oldBufferPosition)
      newTabStops = @tabStopsForBufferPosition(newBufferPosition)

      @destroy() unless _.intersect(oldTabStops, newTabStops).length

  placeTabStopAnchorRanges: (startPosition, tabStopRanges) ->
    @tabStopAnchorRanges = tabStopRanges.map ({start, end}) =>
      @editSession.addAnchorRange([startPosition.add(start), startPosition.add(end)])
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
    anchorRange.destroy() for anchorRange in @tabStopAnchorRanges
    @editSession.off '.snippet-expansion'
    @editSession.snippetExpansion = null

  restore: (@editSession) ->
    @editSession.snippetExpansion = this
    @tabStopAnchorRanges = @tabStopAnchorRanges.map (anchorRange) =>
      @editSession.addAnchorRange(anchorRange.getBufferRange())
