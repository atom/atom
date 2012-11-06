Point = require 'point'
Range = require 'range'
Anchor = require 'anchor'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class Cursor
  screenPosition: null
  bufferPosition: null
  goalColumn: null
  wordRegex: /(\w+)|([^\w\n]+)/g
  visible: true

  constructor: ({@editSession, screenPosition, bufferPosition}) ->
    @anchor = @editSession.addAnchor(strong: true)
    @anchor.on 'change-screen-position', (args...) => @trigger 'change-screen-position', args...
    @setScreenPosition(screenPosition) if screenPosition
    @setBufferPosition(bufferPosition) if bufferPosition

  destroy: ->
    @anchor.destroy()
    @editSession.removeCursor(this)
    @trigger 'destroy'

  setScreenPosition: (screenPosition, options) ->
    @goalColumn = null
    @clearSelection()
    @anchor.setScreenPosition(screenPosition, options)

  getScreenPosition: ->
    @anchor.getScreenPosition()

  getScreenRow: ->
    @anchor.getScreenRow()

  setBufferPosition: (bufferPosition, options) ->
    @goalColumn = null
    @clearSelection()
    @anchor.setBufferPosition(bufferPosition, options)

  getBufferPosition: ->
    @anchor.getBufferPosition()

  setVisible: (visible) ->
    if @visible != visible
      @visible = visible
      @trigger 'change-visibility', @visible

  isVisible: -> @visible

  clearSelection: ->
    if @selection
      @selection.clear() unless @selection.retainSelection

  getScreenRow: ->
    @getScreenPosition().row

  getScreenColumn: ->
    @getScreenPosition().column

  getBufferRow: ->
    @getBufferPosition().row

  getBufferColumn: ->
    @getBufferPosition().column

  getCurrentBufferLine: ->
    @editSession.lineForBufferRow(@getBufferRow())

  refreshScreenPosition: ->
    @anchor.refreshScreenPosition()

  moveUp: (rowCount = 1) ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - rowCount, column: column})
    @goalColumn = column

  moveDown: (rowCount = 1) ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + rowCount, column: column})
    @goalColumn = column

  moveLeft: ->
    { row, column } = @getScreenPosition()
    [row, column] = if column > 0 then [row, column - 1] else [row - 1, Infinity]
    @setScreenPosition({row, column})

  moveRight: ->
    { row, column } = @getScreenPosition()
    @setScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true)

  moveToTop: ->
    @setBufferPosition([0,0])

  moveToBottom: ->
    @setBufferPosition(@editSession.getEofBufferPosition())

  moveToBeginningOfLine: ->
    @setBufferPosition([@getBufferRow(), 0])

  moveToFirstCharacterOfLine: ->
    position = @getBufferPosition()
    range = @editSession.bufferRangeForBufferRow(position.row)
    newPosition = null
    @editSession.scanInRange /^\s*/, range, (match, matchRange) =>
      newPosition = matchRange.end
    return unless newPosition
    newPosition = [position.row, 0] if newPosition.isEqual(position)
    @setBufferPosition(newPosition)

  skipLeadingWhitespace: ->
    position = @getBufferPosition()
    range = @editSession.bufferRangeForBufferRow(position.row)
    endOfLeadingWhitespace = null
    @editSession.scanInRange /^[ \t]*/, range, (match, matchRange) =>
      endOfLeadingWhitespace = matchRange.end

    @setBufferPosition(endOfLeadingWhitespace) if endOfLeadingWhitespace.isGreaterThan(position)

  moveToEndOfLine: ->
    @setBufferPosition([@getBufferRow(), Infinity])

  moveToBeginningOfWord: ->
    @setBufferPosition(@getBeginningOfCurrentWordBufferPosition())

  moveToEndOfWord: ->
    @setBufferPosition(@getEndOfCurrentWordBufferPosition())

  getBeginningOfCurrentWordBufferPosition: (options = {}) ->
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editSession.buffer.previousNonBlankRow(currentBufferPosition.row)
    previousLinesRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = currentBufferPosition
    @editSession.backwardsScanInRange @wordRegex, previousLinesRange, (match, matchRange, { stop }) =>
      if matchRange.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
        beginningOfWordPosition = matchRange.start
      stop()
    beginningOfWordPosition

  getEndOfCurrentWordBufferPosition: (options = {}) ->
    allowNext = options.allowNext ? true
    currentBufferPosition = @getBufferPosition()
    range = [currentBufferPosition, @editSession.getEofBufferPosition()]

    endOfWordPosition = null
    @editSession.scanInRange @wordRegex, range, (match, matchRange, { stop }) =>
      endOfWordPosition = matchRange.end
      if not allowNext and matchRange.start.isGreaterThan(currentBufferPosition)
        endOfWordPosition = currentBufferPosition
      stop()
    endOfWordPosition

  getCurrentWordBufferRange: ->
    new Range(@getBeginningOfCurrentWordBufferPosition(allowPrevious: false), @getEndOfCurrentWordBufferPosition(allowNext: false))

  getCurrentLineBufferRange: ->
    @editSession.bufferRangeForBufferRow(@getBufferRow())

  getCurrentWordPrefix: ->
    @editSession.getTextInBufferRange([@getBeginningOfCurrentWordBufferPosition(), @getBufferPosition()])

  isAtBeginningOfLine: ->
    @getBufferPosition().column == 0

  getIndentLevel: ->
    if @editSession.softTabs
      @getBufferColumn() / @editSession.getTabLength()
    else
      @getBufferColumn()

  isAtEndOfLine: ->
    @getBufferPosition().isEqual(@getCurrentLineBufferRange().end)

_.extend Cursor.prototype, EventEmitter
