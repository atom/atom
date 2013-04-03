Point = require 'point'
Range = require 'range'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class Cursor
  screenPosition: null
  bufferPosition: null
  goalColumn: null
  visible: true
  needsAutoscroll: null

  constructor: ({@editSession, @marker}) ->
    @editSession.observeMarker @marker, (e) =>
      @setVisible(@selection.isEmpty())

      {oldHeadScreenPosition, newHeadScreenPosition} = e
      {oldHeadBufferPosition, newHeadBufferPosition} = e
      {bufferChanged} = e
      return if oldHeadScreenPosition.isEqual(newHeadScreenPosition)

      @needsAutoscroll ?= @isLastCursor() and !bufferChanged

      movedEvent =
        oldBufferPosition: oldHeadBufferPosition
        oldScreenPosition: oldHeadScreenPosition
        newBufferPosition: newHeadBufferPosition
        newScreenPosition: newHeadScreenPosition
        bufferChanged: bufferChanged

      @trigger 'moved', movedEvent
      @editSession.trigger 'cursor-moved', movedEvent
    @needsAutoscroll = true

  destroy: ->
    @editSession.destroyMarker(@marker)
    @editSession.removeCursor(this)
    @trigger 'destroyed'

  setScreenPosition: (screenPosition, options={}) ->
    @changePosition options, =>
      @editSession.setMarkerHeadScreenPosition(@marker, screenPosition, options)

  getScreenPosition: ->
    @editSession.getMarkerHeadScreenPosition(@marker)

  setBufferPosition: (bufferPosition, options={}) ->
    @changePosition options, =>
      @editSession.setMarkerHeadBufferPosition(@marker, bufferPosition, options)

  getBufferPosition: ->
    @editSession.getMarkerHeadBufferPosition(@marker)

  changePosition: (options, fn) ->
    @goalColumn = null
    @clearSelection()
    @needsAutoscroll = options.autoscroll ? @isLastCursor()
    unless fn()
      @trigger 'autoscrolled' if @needsAutoscroll

  setVisible: (visible) ->
    if @visible != visible
      @visible = visible
      @needsAutoscroll ?= true if @visible and @isLastCursor()
      @trigger 'visibility-changed', @visible

  isVisible: -> @visible

  wordRegExp: ->
    nonWordCharacters = config.get("editor.nonWordCharacters")
    new RegExp("^[\t ]*$|[^\\s#{_.escapeRegExp(nonWordCharacters)}]+|[#{_.escapeRegExp(nonWordCharacters)}]+", "g")

  isLastCursor: ->
    this == @editSession.getCursor()

  isSurroundedByWhitespace: ->
    {row, column} = @getBufferPosition()
    range = [[row, Math.min(0, column - 1)], [row, Math.max(0, column + 1)]]
    /^\s+$/.test @editSession.getTextInBufferRange(range)

  clearAutoscroll: ->
    @needsAutoscroll = null

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
    scanRange = @getCurrentLineBufferRange()
    newPosition = null
    @editSession.scanInRange /^\s*/, scanRange, ({range}) =>
      newPosition = range.end
    return unless newPosition
    newPosition = [position.row, 0] if newPosition.isEqual(position)
    @setBufferPosition(newPosition)

  skipLeadingWhitespace: ->
    position = @getBufferPosition()
    scanRange = @getCurrentLineBufferRange()
    endOfLeadingWhitespace = null
    @editSession.scanInRange /^[ \t]*/, scanRange, ({range}) =>
      endOfLeadingWhitespace = range.end

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
    scanRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = null
    @editSession.backwardsScanInRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      if range.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
        beginningOfWordPosition = range.start
      if not beginningOfWordPosition?.isEqual(currentBufferPosition)
        stop()

    beginningOfWordPosition or currentBufferPosition

  getEndOfCurrentWordBufferPosition: (options = {}) ->
    allowNext = options.allowNext ? true
    currentBufferPosition = @getBufferPosition()
    scanRange = [currentBufferPosition, @editSession.getEofBufferPosition()]

    endOfWordPosition = null
    @editSession.scanInRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      if range.start.isLessThanOrEqual(currentBufferPosition) or allowNext
        endOfWordPosition = range.end
      if not endOfWordPosition?.isEqual(currentBufferPosition)
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
