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
    @editor.scanRegexMatchesInRange @wordRegex, range, (match, matchRange, { stop }) =>
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

    @editor.scanRegexMatchesInRange @wordRegex, range, (match, matchRange, { stop }) =>
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
    @editor.scanRegexMatchesInRange /^\s*/, range, (match, matchRange) =>
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
    screenPosition = @getScreenPosition()
    position = @editor.pixelPositionForScreenPosition(screenPosition)
    @css(position)

    if @editor.getCursors().length == 1 or @editor.screenPositionInBounds(screenPosition)
      @editor.scrollTo(position)
