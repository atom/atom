{View} = require 'space-pen'
Anchor = require 'anchor'
Point = require 'point'
Range = require 'range'
_ = require 'underscore'

module.exports =
class Cursor extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  anchor: null
  editor: null
  wordRegex: /(\w+)|([^\w\s]+)/g

  initialize: ({editor, screenPosition} = {}) ->
    @editor = editor
    @anchor = new Anchor(@editor, screenPosition)
    @selection = @editor.compositeSelection.addSelectionForCursor(this)

  afterAttach: (onDom) ->
    return unless onDom
    @updateAppearance()
    @editor.syncCursorAnimations()

  handleBufferChange: (e) ->
    @anchor.handleBufferChange(e)
    @refreshScreenPosition()
    @trigger 'cursor-move', bufferChange: true

  remove: ->
    @editor.compositeCursor.removeCursor(this)
    @editor.compositeSelection.removeSelectionForCursor(this)
    super

  getBufferPosition: ->
    @anchor.getBufferPosition()

  setBufferPosition: (bufferPosition, options={}) ->
    @anchor.setBufferPosition(bufferPosition, options)
    @refreshScreenPosition()
    @trigger 'cursor-move', bufferChange: false
    @clearSelection()

  getScreenPosition: ->
    @anchor.getScreenPosition()

  setScreenPosition: (position, options={}) ->
    @anchor.setScreenPosition(position, options)
    @refreshScreenPosition(position, options)
    @trigger 'cursor-move', bufferChange: false
    @clearSelection()

  refreshScreenPosition: ->
    @goalColumn = null
    @updateAppearance()

    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  resetCursorAnimation: ->
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @removeClass 'idle'
    _.defer => @addClass 'idle'

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
    @editor.scanInRange @wordRegex, range, (match, matchRange, { stop }) =>
      if matchRange.start.isGreaterThan(bufferPosition)
        nextPosition = matchRange.start
        stop()

    @setBufferPosition(nextPosition or @editor.getEofPosition())

  moveToBeginningOfWord: ->
    @setBufferPosition(@getBeginningOfCurrentWordBufferPosition())

  moveToEndOfWord: ->
    @setBufferPosition(@getEndOfCurrentWordBufferPosition())

  getBeginningOfCurrentWordBufferPosition: (options = {}) ->
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = @getBufferPosition()

    previousRow = Math.max(0, currentBufferPosition.row - 1)
    previousLinesRange = [[previousRow, 0], currentBufferPosition]
    beginningOfWordPosition = currentBufferPosition

    @editor.backwardsScanInRange @wordRegex, previousLinesRange, (match, matchRange, { stop }) =>
      if matchRange.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
        beginningOfWordPosition = matchRange.start
      stop()

    beginningOfWordPosition

  getEndOfCurrentWordBufferPosition: (options = {}) ->
    allowNext = options.allowNext ? true
    position = null
    bufferPosition = @getBufferPosition()
    range = [bufferPosition, @editor.getEofPosition()]
    @editor.scanInRange @wordRegex, range, (match, matchRange, { stop }) =>
      position = matchRange.end
      if not allowNext and matchRange.start.isGreaterThan(bufferPosition)
        position = bufferPosition
      stop()
    position

  getCurrentWordBufferRange: ->
    new Range(@getBeginningOfCurrentWordBufferPosition(allowPrevious: false), @getEndOfCurrentWordBufferPosition(allowNext: false))

  getCurrentLineBufferRange: ->
    @editor.rangeForBufferRow(@getBufferPosition().row)

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
    @editor.scanInRange /^\s*/, range, (match, matchRange) =>
      newPosition = matchRange.end
    return unless newPosition
    newPosition = [position.row, 0] if newPosition.isEqual(position)
    @setBufferPosition(newPosition)

  moveRight: ->
    { row, column } = @getScreenPosition()
    @setScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true)

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
    pixelPosition = @editor.pixelPositionForScreenPosition(screenPosition)
    @css(pixelPosition)

    if this == _.last(@editor.getCursors())
      @editor.scrollTo(pixelPosition)

    if @editor.isFoldedAtScreenRow(screenPosition.row)
      @hide()
    else
      @show()

    @selection.updateAppearance()
