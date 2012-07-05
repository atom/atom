module.exports =
class SnippetExpansion
  tabStopAnchorRanges: null

  constructor: (snippet, @editSession) ->
    @editSession.selectToBeginningOfWord()
    startPosition = @editSession.getCursorBufferPosition()
    @editSession.insertText(snippet.body)
    if snippet.tabStops.length
      @placeTabStopAnchorRanges(startPosition, snippet.tabStops)
    if snippet.lineCount > 1
      @indentSubsequentLines(startPosition.row, snippet)

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
    @editSession.setSelectedBufferRange(@tabStopAnchorRanges[@tabStopIndex].getBufferRange())

  cursorIsInsideTabStops: ->
    position = @editSession.getCursorBufferPosition()
    for anchorRange in @tabStopAnchorRanges
      return true if anchorRange.containsBufferPosition(position)
    false

  destroy: ->
    anchorRange.destroy() for anchorRange in @tabStopAnchorRanges
    @editSession.snippetExpansion = null
