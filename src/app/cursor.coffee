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
  wordRegex: /(\w+)|([^\w\s]+)/g

  constructor: ({@editSession, screenPosition, bufferPosition}) ->
    @anchor = @editSession.addAnchor()
    @anchor.on 'change-screen-position', (args...) => @trigger 'change-screen-position', args...
    @setScreenPosition(screenPosition) if screenPosition
    @setBufferPosition(bufferPosition) if bufferPosition

  destroy: ->
    @editSession.removeAnchor(@anchor)
    @editSession.removeCursor(this)
    @trigger 'destroy'

  setScreenPosition: (screenPosition, options) ->
    @goalColumn = null
    @clearSelection()
    @anchor.setScreenPosition(screenPosition, options)

  getScreenPosition: ->
    @anchor.getScreenPosition()

  setBufferPosition: (bufferPosition, options) ->
    @goalColumn = null
    @clearSelection()
    @anchor.setBufferPosition(bufferPosition, options)

  getBufferPosition: ->
    @anchor.getBufferPosition()

  clearSelection: ->
    if @selection
      @selection.clear() unless @selection.retainSelection

  getScreenRow: ->
    @getScreenPosition().row

  getBufferRow: ->
    @getBufferPosition().row

  getCurrentBufferLine: ->
    @editSession.lineForBufferRow(@getBufferRow())

  refreshScreenPosition: ->
    @anchor.refreshScreenPosition()

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

  moveToEndOfLine: ->
    @setBufferPosition([@getBufferRow(), Infinity])

  moveToBeginningOfWord: ->
    @setBufferPosition(@getBeginningOfCurrentWordBufferPosition())

  moveToEndOfWord: ->
    @setBufferPosition(@getEndOfCurrentWordBufferPosition())

  moveToNextWord: ->
    @setBufferPosition(@getBeginningOfNextWordBufferPosition())

  getBeginningOfCurrentWordBufferPosition: (options = {}) ->
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = @getBufferPosition()
    previousRow = Math.max(0, currentBufferPosition.row - 1)
    previousLinesRange = [[previousRow, 0], currentBufferPosition]

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

  getBeginningOfNextWordBufferPosition: ->
    currentBufferPosition = @getBufferPosition()
    eofBufferPosition = @editSession.getEofBufferPosition()
    range = [currentBufferPosition, eofBufferPosition]

    nextWordPosition = eofBufferPosition
    @editSession.scanInRange @wordRegex, range, (match, matchRange, { stop }) =>
      if matchRange.start.isGreaterThan(currentBufferPosition)
        nextWordPosition = matchRange.start
        stop()
    nextWordPosition

  getCurrentWordBufferRange: ->
    new Range(@getBeginningOfCurrentWordBufferPosition(allowPrevious: false), @getEndOfCurrentWordBufferPosition(allowNext: false))

  getCurrentLineBufferRange: ->
    @editSession.bufferRangeForBufferRow(@getBufferRow())

  isAtBeginningOfLine: ->
    @getBufferPosition().column == 0

  isAtEndOfLine: ->
    @getBufferPosition().isEqual(@getCurrentLineBufferRange().end)

_.extend Cursor.prototype, EventEmitter
