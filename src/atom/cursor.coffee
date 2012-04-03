{View} = require 'space-pen'
Anchor = require 'anchor'
Point = require 'point'
_ = require 'underscore'

module.exports =
class Cursor extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  anchor: null
  editor: null
  wordRegex: /(\w+)|([^\w\s]+)/g

  initialize: (@editor) ->
    @anchor = new Anchor(@editor)
    @selection = @editor.compositeSelection.addSelectionForCursor(this)
    @one 'attach', => @updateAppearance()

  handleBufferChange: (e) ->
    @anchor.handleBufferChange(e)
    @refreshScreenPosition()

  remove: ->
    @editor.compositeCursor.removeCursor(this)
    @editor.compositeSelection.removeSelectionForCursor(this)
    super

  getBufferPosition: ->
    @anchor.getBufferPosition()

  setBufferPosition: (bufferPosition) ->
    @anchor.setBufferPosition(bufferPosition)
    @refreshScreenPosition()
    @clearSelection()

  getScreenPosition: ->
    @anchor.getScreenPosition()

  setScreenPosition: (position, options={}) ->
    @anchor.setScreenPosition(position, options)
    @refreshScreenPosition(position, options)
    @clearSelection()

  refreshScreenPosition: ->
    @goalColumn = null
    @updateAppearance()
    @trigger 'cursor:position-changed'

    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  clearSelection: ->
    @selection.clearSelection() unless @selection.retainSelection

  getCurrentBufferLine: ->
    @editor.lineForBufferRow(@getBufferPosition().row)

  isOnEOL: ->
    @getScreenPosition().column == @getCurrentBufferLine().length

  moveUp: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - 1, column: column})
    @goalColumn = column

  moveDown: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + 1, column: column})
    @goalColumn = column

  moveToNextWord: ->
    bufferPosition = @getBufferPosition()
    range = [bufferPosition, @editor.getEofPosition()]

    nextPosition = null
    @editor.traverseRegexMatchesInRange @wordRegex, range, (match, matchRange, { stop }) =>
      if matchRange.start.isGreaterThan(bufferPosition)
        nextPosition = matchRange.start
        stop()

    @setBufferPosition(nextPosition or @editor.getEofPosition())

  moveToBeginningOfWord: ->
    bufferPosition = @getBufferPosition()
    range = [[0,0], bufferPosition]
    @editor.backwardsTraverseRegexMatchesInRange @wordRegex, range, (match, matchRange, { stop }) =>
      @setBufferPosition matchRange.start
      stop()

  moveToEndOfWord: ->
    bufferPosition = @getBufferPosition()
    range = [bufferPosition, @editor.getEofPosition()]

    @editor.traverseRegexMatchesInRange @wordRegex, range, (match, matchRange, { stop }) =>
      @setBufferPosition matchRange.end
      stop()

  moveToEndOfLine: ->
    { row } = @getBufferPosition()
    @setBufferPosition({ row, column: @editor.buffer.lineForRow(row).length })

  moveToBeginningOfLine: ->
    { row } = @getScreenPosition()
    @setScreenPosition({ row, column: 0 })

  moveToFirstCharacterOfLine: ->
    position = @getBufferPosition()
    range = @editor.rangeForBufferRow(position.row)
    newPosition = null
    @editor.traverseRegexMatchesInRange /^\s*/, range, (match, matchRange) =>
      newPosition = matchRange.end
    newPosition = [position.row, 0] if newPosition.isEqual(position)
    @setBufferPosition(newPosition)

  moveRight: ->
    { row, column } = @getScreenPosition()
    @setScreenPosition(@editor.clipScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true))

  moveLeft: ->
    { row, column } = @getScreenPosition()
    [row, column] = if column > 0 then [row, column - 1] else [row - 1, Infinity]
    @setScreenPosition({row, column})

  moveToTop: ->
    @setBufferPosition [0,0]

  moveToBottom: ->
    @setBufferPosition @editor.getEofPosition()

  updateAppearance: ->
    position = @editor.pixelPositionForScreenPosition(@getScreenPosition())
    @css(position)
    _.defer =>
      @autoScrollVertically(position)
      @autoScrollHorizontally(position)

  autoScrollVertically: (position) ->
    linesInView = @editor.height() / @height()
    maxScrollMargin = Math.floor((linesInView - 1) / 2)
    scrollMargin = Math.min(@editor.vScrollMargin, maxScrollMargin)
    margin = scrollMargin * @height()
    desiredTop = position.top - margin
    desiredBottom = position.top + @height() + margin

    if desiredBottom > @editor.scrollBottom()
      @editor.scrollBottom(desiredBottom)
    else if desiredTop < @editor.scrollTop()
      @editor.scrollTop(desiredTop)

  autoScrollHorizontally: (position) ->
    return if @editor.softWrap

    charsInView = @editor.horizontalScroller.width() / @width()
    maxScrollMargin = Math.floor((charsInView - 1) / 2)
    scrollMargin = Math.min(@editor.hScrollMargin, maxScrollMargin)
    margin = scrollMargin * @width()
    desiredRight = position.left + @width() + margin
    desiredLeft = position.left - margin

    if desiredRight > @editor.horizontalScroller.scrollRight()
      @editor.horizontalScroller.scrollRight(desiredRight)
    else if desiredLeft < @editor.horizontalScroller.scrollLeft()
      @editor.horizontalScroller.scrollLeft(desiredLeft)

