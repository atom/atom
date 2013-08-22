{Point, Range} = require 'telepath'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

# Public: The `Cursor` class represents the little blinking line identifying where text can be inserted.
#
# Cursors have some metadata attached in the form of a {StringMarker}.
module.exports =
class Cursor
  _.extend @prototype, EventEmitter

  screenPosition: null
  bufferPosition: null
  goalColumn: null
  visible: true
  needsAutoscroll: null

  ### Internal ###

  constructor: ({@editSession, @marker}) ->
    @updateVisibility()
    @marker.on 'changed', (e) =>
      @updateVisibility()
      {oldHeadScreenPosition, newHeadScreenPosition} = e
      {oldHeadBufferPosition, newHeadBufferPosition} = e
      {textChanged} = e
      return if oldHeadScreenPosition.isEqual(newHeadScreenPosition)

      @needsAutoscroll ?= @isLastCursor() and !textChanged

      movedEvent =
        oldBufferPosition: oldHeadBufferPosition
        oldScreenPosition: oldHeadScreenPosition
        newBufferPosition: newHeadBufferPosition
        newScreenPosition: newHeadScreenPosition
        textChanged: textChanged

      @trigger 'moved', movedEvent
      @editSession.trigger 'cursor-moved', movedEvent
    @marker.on 'destroyed', =>
      @destroyed = true
      @editSession.removeCursor(this)
      @trigger 'destroyed'
    @needsAutoscroll = true

  destroy: ->
    @marker.destroy()

  changePosition: (options, fn) ->
    @goalColumn = null
    @clearSelection()
    @needsAutoscroll = options.autoscroll ? @isLastCursor()
    unless fn()
      @trigger 'autoscrolled' if @needsAutoscroll

  ### Public ###

  # Moves a cursor to a given screen position.
  #
  # screenPosition - An {Array} of two numbers: the screen row, and the screen column.
  # options - An object with the following keys:
  #           autoscroll: A {Boolean} which, if `true`, scrolls the {EditSession} to wherever the cursor moves to
  #
  setScreenPosition: (screenPosition, options={}) ->
    @changePosition options, =>
      @marker.setHeadScreenPosition(screenPosition, options)

  # Gets the screen position of the cursor.
  #
  # Returns an {Array} of two numbers: the screen row, and the screen column.
  getScreenPosition: ->
    @marker.getHeadScreenPosition()

  # Moves a cursor to a given buffer position.
  #
  # bufferPosition - An {Array} of two numbers: the buffer row, and the buffer column.
  # options - An object with the following keys:
  #           autoscroll: A {Boolean} which, if `true`, scrolls the {EditSession} to wherever the cursor moves to
  #
  setBufferPosition: (bufferPosition, options={}) ->
    @changePosition options, =>
      @marker.setHeadBufferPosition(bufferPosition, options)

  # Gets the current buffer position.
  #
  # Returns an {Array} of two numbers: the buffer row, and the buffer column.
  getBufferPosition: ->
    @marker.getHeadBufferPosition()

  # If the marker range is empty, the cursor is marked as being visible.
  updateVisibility: ->
    @setVisible(@marker.getBufferRange().isEmpty())

  # Sets the visibility of the cursor.
  #
  # visible - A {Boolean} indicating whether the cursor should be visible
  setVisible: (visible) ->
    if @visible != visible
      @visible = visible
      @needsAutoscroll ?= true if @visible and @isLastCursor()
      @trigger 'visibility-changed', @visible

  # Retrieves the visibility of the cursor.
  #
  # Returns a {Boolean}.
  isVisible: -> @visible

  # Identifies what the cursor considers a "word" RegExp.
  #
  # Returns a {RegExp}.
  wordRegExp: ->
    nonWordCharacters = config.get("editor.nonWordCharacters")
    new RegExp("^[\t ]*$|[^\\s#{_.escapeRegExp(nonWordCharacters)}]+|[#{_.escapeRegExp(nonWordCharacters)}]+", "g")

  # Identifies if this cursor is the last in the {EditSession}.
  #
  # "Last" is defined as the most recently added cursor.
  #
  # Returns a {Boolean}.
  isLastCursor: ->
    this == @editSession.getCursor()

  # Identifies if the cursor is surrounded by whitespace.
  #
  # "Surrounded" here means that all characters before and after the cursor is whitespace.
  #
  # Returns a {Boolean}.
  isSurroundedByWhitespace: ->
    {row, column} = @getBufferPosition()
    range = [[row, Math.min(0, column - 1)], [row, Math.max(0, column + 1)]]
    /^\s+$/.test @editSession.getTextInBufferRange(range)

  isInsideWord: ->
    {row, column} = @getBufferPosition()
    range = [[row, column], [row, Infinity]]
    @editSession.getTextInBufferRange(range).search(@wordRegExp()) == 0

  # Removes the setting for auto-scroll.
  clearAutoscroll: ->
    @needsAutoscroll = null

  # Deselects whatever the cursor is selecting.
  clearSelection: ->
    @selection?.clear()

  # Retrieves the cursor's screen row.
  #
  # Returns a {Number}.
  getScreenRow: ->
    @getScreenPosition().row

  # Retrieves the cursor's screen column.
  #
  # Returns a {Number}.
  getScreenColumn: ->
    @getScreenPosition().column

  # Retrieves the cursor's buffer row.
  #
  # Returns a {Number}.
  getBufferRow: ->
    @getBufferPosition().row

  # Retrieves the cursor's buffer column.
  #
  # Returns a {Number}.
  getBufferColumn: ->
    @getBufferPosition().column

  # Retrieves the cursor's buffer row text.
  #
  # Returns a {String}.
  getCurrentBufferLine: ->
    @editSession.lineForBufferRow(@getBufferRow())

  # Moves the cursor up one screen row.
  moveUp: (rowCount = 1, {moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      { row, column } = range.start
    else
      { row, column } = @getScreenPosition()

    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - rowCount, column: column})
    @goalColumn = column

  # Moves the cursor down one screen row.
  moveDown: (rowCount = 1, {moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      { row, column } = range.end
    else
      { row, column } = @getScreenPosition()

    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + rowCount, column: column})
    @goalColumn = column

  # Moves the cursor left one screen column.
  #
  # options -
  #   moveToEndOfSelection: true will move to the left of the selection if a selection
  moveLeft: ({moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      @setScreenPosition(range.start)
    else
      {row, column} = @getScreenPosition()
      [row, column] = if column > 0 then [row, column - 1] else [row - 1, Infinity]
      @setScreenPosition({row, column})

  # Moves the cursor right one screen column.
  #
  # options -
  #   moveToEndOfSelection: true will move to the right of the selection if a selection
  moveRight: ({moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      @setScreenPosition(range.end)
    else
      { row, column } = @getScreenPosition()
      @setScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true)

  # Moves the cursor to the top of the buffer.
  moveToTop: ->
    @setBufferPosition([0,0])

  # Moves the cursor to the bottom of the buffer.
  moveToBottom: ->
    @setBufferPosition(@editSession.getEofBufferPosition())

  # Moves the cursor to the beginning of the screen line.
  moveToBeginningOfLine: ->
    @setScreenPosition([@getScreenRow(), 0])

  # Moves the cursor to the beginning of the first character in the line.
  moveToFirstCharacterOfLine: ->
    {row, column} = @getScreenPosition()
    screenline = @editSession.lineForScreenRow(row)

    goalColumn = screenline.text.search(/\S/)
    return if goalColumn == -1

    goalColumn = 0 if goalColumn == column
    @setScreenPosition([row, goalColumn])

  # Moves the cursor to the beginning of the buffer line, skipping all whitespace.
  skipLeadingWhitespace: ->
    position = @getBufferPosition()
    scanRange = @getCurrentLineBufferRange()
    endOfLeadingWhitespace = null
    @editSession.scanInBufferRange /^[ \t]*/, scanRange, ({range}) =>
      endOfLeadingWhitespace = range.end

    @setBufferPosition(endOfLeadingWhitespace) if endOfLeadingWhitespace.isGreaterThan(position)

  # Moves the cursor to the end of the buffer line.
  moveToEndOfLine: ->
    @setScreenPosition([@getScreenRow(), Infinity])

  # Moves the cursor to the beginning of the word.
  moveToBeginningOfWord: ->
    @setBufferPosition(@getBeginningOfCurrentWordBufferPosition())

  # Moves the cursor to the end of the word.
  moveToEndOfWord: ->
    if position = @getEndOfCurrentWordBufferPosition()
      @setBufferPosition(position)

  # Moves the cursor to the beginning of the next word.
  moveToBeginningOfNextWord: ->
    if position = @getBeginningOfNextWordBufferPosition()
      @setBufferPosition(position)

  # Moves the cursor to the previous word boundary.
  moveToPreviousWordBoundary: ->
    if position = @getPreviousWordBoundaryBufferPosition()
      @setBufferPosition(position)

  # Moves the cursor to the next word boundary.
  moveToNextWordBoundary: ->
    if position = @getMoveNextWordBoundaryBufferPosition()
      @setBufferPosition(position)

  # Retrieves the buffer position of where the current word starts.
  #
  # options - A hash with one option:
  #           wordRegex: A {RegExp} indicating what constitutes a "word" (default: {wordRegExp})
  #
  # Returns a {Range}.
  getBeginningOfCurrentWordBufferPosition: (options = {}) ->
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editSession.buffer.previousNonBlankRow(currentBufferPosition.row)
    scanRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = null
    @editSession.backwardsScanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      if range.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
        beginningOfWordPosition = range.start
      if not beginningOfWordPosition?.isEqual(currentBufferPosition)
        stop()

    beginningOfWordPosition or currentBufferPosition

  # Retrieves buffer position of previous word boiundry. It might be on the
  # current word, or the previous word.
  getPreviousWordBoundaryBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editSession.buffer.previousNonBlankRow(currentBufferPosition.row)
    scanRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = null
    @editSession.backwardsScanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      if range.start.row < currentBufferPosition.row and currentBufferPosition.column > 0
        # force it to stop at the beginning of each line
        beginningOfWordPosition = new Point(currentBufferPosition.row, 0)
      else if range.end.isLessThan(currentBufferPosition)
        beginningOfWordPosition = range.end
      else
        beginningOfWordPosition = range.start

      if not beginningOfWordPosition?.isEqual(currentBufferPosition)
        stop()

    beginningOfWordPosition or currentBufferPosition

  # Retrieves buffer position of previous word boiundry. It might be on the
  # current word, or the previous word.
  getMoveNextWordBoundaryBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    scanRange = [currentBufferPosition, @editSession.getEofBufferPosition()]

    endOfWordPosition = null
    @editSession.scanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      if range.start.row > currentBufferPosition.row
        # force it to stop at the beginning of each line
        endOfWordPosition = new Point(range.start.row, 0)
      else if range.start.isGreaterThan(currentBufferPosition)
        endOfWordPosition = range.start
      else
        endOfWordPosition = range.end

      if not endOfWordPosition?.isEqual(currentBufferPosition)
        stop()

    endOfWordPosition or currentBufferPosition

  # Retrieves the buffer position of where the current word ends.
  #
  # options - A hash with one option:
  #           wordRegex: A {RegExp} indicating what constitutes a "word" (default: {wordRegExp})
  #
  # Returns a {Range}.
  getEndOfCurrentWordBufferPosition: (options = {}) ->
    allowNext = options.allowNext ? true
    currentBufferPosition = @getBufferPosition()
    scanRange = [currentBufferPosition, @editSession.getEofBufferPosition()]

    endOfWordPosition = null
    @editSession.scanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      if range.start.isLessThanOrEqual(currentBufferPosition) or allowNext
        endOfWordPosition = range.end
      if not endOfWordPosition?.isEqual(currentBufferPosition)
        stop()

    endOfWordPosition ? currentBufferPosition

  # Retrieves the buffer position of where the next word starts.
  #
  # options - A hash with one option:
  #           wordRegex: A {RegExp} indicating what constitutes a "word" (default: {wordRegExp})
  #
  # Returns a {Range}.
  getBeginningOfNextWordBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    start = if @isInsideWord() then @getEndOfCurrentWordBufferPosition() else currentBufferPosition
    scanRange = [start, @editSession.getEofBufferPosition()]

    beginningOfNextWordPosition = null
    @editSession.scanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      beginningOfNextWordPosition = range.start
      stop()

    beginningOfNextWordPosition or currentBufferPosition

  # Gets the word located under the cursor.
  #
  # options - An object with properties based on {.getBeginningOfCurrentWordBufferPosition}.
  #
  # Returns a {String}.
  getCurrentWordBufferRange: (options={}) ->
    startOptions = _.extend(_.clone(options), allowPrevious: false)
    endOptions = _.extend(_.clone(options), allowNext: false)
    new Range(@getBeginningOfCurrentWordBufferPosition(startOptions), @getEndOfCurrentWordBufferPosition(endOptions))

  # Retrieves the range for the current line.
  #
  # options - A hash with the same keys as {EditSession.bufferRangeForBufferRow}
  #
  # Returns a {Range}.
  getCurrentLineBufferRange: (options) ->
    @editSession.bufferRangeForBufferRow(@getBufferRow(), options)

  # Retrieves the range for the current paragraph.
  #
  # A paragraph is defined as a block of text surrounded by empty lines.
  #
  # Returns a {Range}.
  getCurrentParagraphBufferRange: ->
    @editSession.languageMode.rowRangeForParagraphAtBufferRow(@getBufferRow())

  # Retrieves the characters that constitute a word preceeding the current cursor position.
  #
  # Returns a {String}.
  getCurrentWordPrefix: ->
    @editSession.getTextInBufferRange([@getBeginningOfCurrentWordBufferPosition(), @getBufferPosition()])

  # Identifies if the cursor is at the start of a line.
  #
  # Returns a {Boolean}.
  isAtBeginningOfLine: ->
    @getBufferPosition().column == 0

  # Retrieves the indentation level of the current line.
  #
  # Returns a {Number}.
  getIndentLevel: ->
    if @editSession.getSoftTabs()
      @getBufferColumn() / @editSession.getTabLength()
    else
      @getBufferColumn()

  # Identifies if the cursor is at the end of a line.
  #
  # Returns a {Boolean}.
  isAtEndOfLine: ->
    @getBufferPosition().isEqual(@getCurrentLineBufferRange().end)

  # Retrieves the grammar's token scopes for the line.
  #
  # Returns an {Array} of {String}s.
  getScopes: ->
    @editSession.scopesForBufferPosition(@getBufferPosition())
