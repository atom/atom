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
  visible: true
  needsAutoscroll: false

  constructor: ({@editSession, screenPosition, bufferPosition}) ->
    @anchor = @editSession.addAnchor(strong: true)
    @anchor.on 'moved', (e) =>
      @needsAutoscroll = (e.autoscroll ? true) and @isLastCursor()
      @trigger 'moved', e
      @editSession.trigger 'cursor-moved', e

    @setScreenPosition(screenPosition) if screenPosition
    @setBufferPosition(bufferPosition) if bufferPosition
    @needsAutoscroll = true

  destroy: ->
    @anchor.destroy()
    @editSession.removeCursor(this)
    @trigger 'destroyed'

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
      @needsAutoscroll = @visible and @isLastCursor()
      @trigger 'visibility-changed', @visible

  isVisible: -> @visible

  wordRegExp: ->
    nonWordCharacters = config.get("editor.nonWordCharacters")
    new RegExp("^[\t ]*$|[^\\s#{_.escapeRegExp(nonWordCharacters)}]+|[#{_.escapeRegExp(nonWordCharacters)}]+", "mg")

  isLastCursor: ->
    this == @editSession.getCursor()

  isSurroundedByWhitespace: ->
    {row, column} = @getBufferPosition()
    range = [[row, Math.min(0, column - 1)], [row, Math.max(0, column + 1)]]
    /^\s+$/.test @editSession.getTextInBufferRange(range)

  autoscrolled: ->
    @needsAutoscroll = false

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
    range = @getCurrentLineBufferRange()
    newPosition = null
    @editSession.scanInRange /^\s*/, range, (match, matchRange) =>
      newPosition = matchRange.end
    return unless newPosition
    newPosition = [position.row, 0] if newPosition.isEqual(position)
    @setBufferPosition(newPosition)

  skipLeadingWhitespace: ->
    position = @getBufferPosition()
    range = @getCurrentLineBufferRange()
    endOfLeadingWhitespace = null
    @editSession.scanInRange /^[ \t]*/, range, (match, matchRange) =>
      endOfLeadingWhitespace = matchRange.end

    @setBufferPosition(endOfLeadingWhitespace) if endOfLeadingWhitespace.isGreaterThan(position)

  moveToEndOfLine: ->
    @setBufferPosition([@getBufferRow(), Infinity])

  moveToBeginningOfWord: ->
    @setBufferPosition(@getBeginningOfCurrentWordBufferPosition())

  moveToEndOfWord: ->
    if position = @getEndOfCurrentWordBufferPosition()
      @setBufferPosition(position)

  getBeginningOfCurrentWordBufferPosition: (options = {}) ->
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editSession.buffer.previousNonBlankRow(currentBufferPosition.row)
    previousLinesRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = currentBufferPosition

    @editSession.backwardsScanInRange (options.wordRegex ? @wordRegExp()), previousLinesRange, (match, matchRange, { stop }) =>
      if matchRange.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
        beginningOfWordPosition = matchRange.start
      stop() unless beginningOfWordPosition.isEqual(currentBufferPosition)

    beginningOfWordPosition

  getEndOfCurrentWordBufferPosition: (options = {}) ->
    allowNext = options.allowNext ? true
    currentBufferPosition = @getBufferPosition()
    range = [currentBufferPosition, @editSession.getEofBufferPosition()]

    endOfWordPosition = null
    @editSession.scanInRange (options.wordRegex ? @wordRegExp()),
    range, (match, matchRange, { stop }) =>
      endOfWordPosition = matchRange.end
      return if endOfWordPosition.isEqual(currentBufferPosition)

      if not allowNext and matchRange.start.isGreaterThan(currentBufferPosition)
        endOfWordPosition = currentBufferPosition
      stop()
    endOfWordPosition or currentBufferPosition

  getCurrentWordBufferRange: (options={}) ->
    startOptions = _.extend(_.clone(options), allowPrevious: false)
    endOptions = _.extend(_.clone(options), allowNext: false)
    new Range(@getBeginningOfCurrentWordBufferPosition(startOptions), @getEndOfCurrentWordBufferPosition(endOptions))

  getCurrentLineBufferRange: (options) ->
    @editSession.bufferRangeForBufferRow(@getBufferRow(), options)

  getCurrentParagraphBufferRange: ->
    row = @getBufferRow()
    return unless /\w/.test(@editSession.lineForBufferRow(row))

    startRow = row
    while startRow > 0
      break unless /\w/.test(@editSession.lineForBufferRow(startRow - 1))
      startRow--

    endRow = row
    lastRow = @editSession.getLastBufferRow()
    while endRow < lastRow
      break unless /\w/.test(@editSession.lineForBufferRow(endRow + 1))
      endRow++

    new Range([startRow, 0], [endRow, @editSession.lineLengthForBufferRow(endRow)])

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

  getScopes: ->
    @editSession.scopesForBufferPosition(@getBufferPosition())

_.extend Cursor.prototype, EventEmitter
