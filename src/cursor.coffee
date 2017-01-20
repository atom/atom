{Point, Range} = require 'text-buffer'
{Emitter} = require 'event-kit'
_ = require 'underscore-plus'
Model = require './model'

EmptyLineRegExp = /(\r\n[\t ]*\r\n)|(\n[\t ]*\n)/g

# Extended: The `Cursor` class represents the little blinking line identifying
# where text can be inserted.
#
# Cursors belong to {TextEditor}s and have some metadata attached in the form
# of a {DisplayMarker}.
module.exports =
class Cursor extends Model
  showCursorOnSelection: null
  screenPosition: null
  bufferPosition: null
  goalColumn: null
  visible: true

  # Instantiated by a {TextEditor}
  constructor: ({@editor, @marker, @showCursorOnSelection, id}) ->
    @emitter = new Emitter

    @showCursorOnSelection ?= true

    @assignId(id)
    @updateVisibility()

  destroy: ->
    @marker.destroy()

  ###
  Section: Event Subscription
  ###

  # Public: Calls your `callback` when the cursor has been moved.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `oldBufferPosition` {Point}
  #     * `oldScreenPosition` {Point}
  #     * `newBufferPosition` {Point}
  #     * `newScreenPosition` {Point}
  #     * `textChanged` {Boolean}
  #     * `Cursor` {Cursor} that triggered the event
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangePosition: (callback) ->
    @emitter.on 'did-change-position', callback

  # Public: Calls your `callback` when the cursor is destroyed
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  # Public: Calls your `callback` when the cursor's visibility has changed
  #
  # * `callback` {Function}
  #   * `visibility` {Boolean}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeVisibility: (callback) ->
    @emitter.on 'did-change-visibility', callback

  ###
  Section: Managing Cursor Position
  ###

  # Public: Moves a cursor to a given screen position.
  #
  # * `screenPosition` {Array} of two numbers: the screen row, and the screen column.
  # * `options` (optional) {Object} with the following keys:
  #   * `autoscroll` A Boolean which, if `true`, scrolls the {TextEditor} to wherever
  #     the cursor moves to.
  setScreenPosition: (screenPosition, options={}) ->
    @changePosition options, =>
      @marker.setHeadScreenPosition(screenPosition, options)

  # Public: Returns the screen position of the cursor as a {Point}.
  getScreenPosition: ->
    @marker.getHeadScreenPosition()

  # Public: Moves a cursor to a given buffer position.
  #
  # * `bufferPosition` {Array} of two numbers: the buffer row, and the buffer column.
  # * `options` (optional) {Object} with the following keys:
  #   * `autoscroll` {Boolean} indicating whether to autoscroll to the new
  #     position. Defaults to `true` if this is the most recently added cursor,
  #     `false` otherwise.
  setBufferPosition: (bufferPosition, options={}) ->
    @changePosition options, =>
      @marker.setHeadBufferPosition(bufferPosition, options)

  # Public: Returns the current buffer position as an Array.
  getBufferPosition: ->
    @marker.getHeadBufferPosition()

  # Public: Returns the cursor's current screen row.
  getScreenRow: ->
    @getScreenPosition().row

  # Public: Returns the cursor's current screen column.
  getScreenColumn: ->
    @getScreenPosition().column

  # Public: Retrieves the cursor's current buffer row.
  getBufferRow: ->
    @getBufferPosition().row

  # Public: Returns the cursor's current buffer column.
  getBufferColumn: ->
    @getBufferPosition().column

  # Public: Returns the cursor's current buffer row of text excluding its line
  # ending.
  getCurrentBufferLine: ->
    @editor.lineTextForBufferRow(@getBufferRow())

  # Public: Returns whether the cursor is at the start of a line.
  isAtBeginningOfLine: ->
    @getBufferPosition().column is 0

  # Public: Returns whether the cursor is on the line return character.
  isAtEndOfLine: ->
    @getBufferPosition().isEqual(@getCurrentLineBufferRange().end)

  ###
  Section: Cursor Position Details
  ###

  # Public: Returns the underlying {DisplayMarker} for the cursor.
  # Useful with overlay {Decoration}s.
  getMarker: -> @marker

  # Public: Identifies if the cursor is surrounded by whitespace.
  #
  # "Surrounded" here means that the character directly before and after the
  # cursor are both whitespace.
  #
  # Returns a {Boolean}.
  isSurroundedByWhitespace: ->
    {row, column} = @getBufferPosition()
    range = [[row, column - 1], [row, column + 1]]
    /^\s+$/.test @editor.getTextInBufferRange(range)

  # Public: Returns whether the cursor is currently between a word and non-word
  # character. The non-word characters are defined by the
  # `editor.nonWordCharacters` config value.
  #
  # This method returns false if the character before or after the cursor is
  # whitespace.
  #
  # Returns a Boolean.
  isBetweenWordAndNonWord: ->
    return false if @isAtBeginningOfLine() or @isAtEndOfLine()

    {row, column} = @getBufferPosition()
    range = [[row, column - 1], [row, column + 1]]
    [before, after] = @editor.getTextInBufferRange(range)
    return false if /\s/.test(before) or /\s/.test(after)

    nonWordCharacters = @getNonWordCharacters()
    nonWordCharacters.includes(before) isnt nonWordCharacters.includes(after)

  # Public: Returns whether this cursor is between a word's start and end.
  #
  # * `options` (optional) {Object}
  #   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  #     (default: {::wordRegExp}).
  #
  # Returns a {Boolean}
  isInsideWord: (options) ->
    {row, column} = @getBufferPosition()
    range = [[row, column], [row, Infinity]]
    @editor.getTextInBufferRange(range).search(options?.wordRegex ? @wordRegExp()) is 0

  # Public: Returns the indentation level of the current line.
  getIndentLevel: ->
    if @editor.getSoftTabs()
      @getBufferColumn() / @editor.getTabLength()
    else
      @getBufferColumn()

  # Public: Retrieves the scope descriptor for the cursor's current position.
  #
  # Returns a {ScopeDescriptor}
  getScopeDescriptor: ->
    @editor.scopeDescriptorForBufferPosition(@getBufferPosition())

  # Public: Returns true if this cursor has no non-whitespace characters before
  # its current position.
  hasPrecedingCharactersOnLine: ->
    bufferPosition = @getBufferPosition()
    line = @editor.lineTextForBufferRow(bufferPosition.row)
    firstCharacterColumn = line.search(/\S/)

    if firstCharacterColumn is -1
      false
    else
      bufferPosition.column > firstCharacterColumn

  # Public: Identifies if this cursor is the last in the {TextEditor}.
  #
  # "Last" is defined as the most recently added cursor.
  #
  # Returns a {Boolean}.
  isLastCursor: ->
    this is @editor.getLastCursor()

  ###
  Section: Moving the Cursor
  ###

  # Public: Moves the cursor up one screen row.
  #
  # * `rowCount` (optional) {Number} number of rows to move (default: 1)
  # * `options` (optional) {Object} with the following keys:
  #   * `moveToEndOfSelection` if true, move to the left of the selection if a
  #     selection exists.
  moveUp: (rowCount=1, {moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      {row, column} = range.start
    else
      {row, column} = @getScreenPosition()

    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - rowCount, column: column}, skipSoftWrapIndentation: true)
    @goalColumn = column

  # Public: Moves the cursor down one screen row.
  #
  # * `rowCount` (optional) {Number} number of rows to move (default: 1)
  # * `options` (optional) {Object} with the following keys:
  #   * `moveToEndOfSelection` if true, move to the left of the selection if a
  #     selection exists.
  moveDown: (rowCount=1, {moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      {row, column} = range.end
    else
      {row, column} = @getScreenPosition()

    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + rowCount, column: column}, skipSoftWrapIndentation: true)
    @goalColumn = column

  # Public: Moves the cursor left one screen column.
  #
  # * `columnCount` (optional) {Number} number of columns to move (default: 1)
  # * `options` (optional) {Object} with the following keys:
  #   * `moveToEndOfSelection` if true, move to the left of the selection if a
  #     selection exists.
  moveLeft: (columnCount=1, {moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      @setScreenPosition(range.start)
    else
      {row, column} = @getScreenPosition()

      while columnCount > column and row > 0
        columnCount -= column
        column = @editor.lineLengthForScreenRow(--row)
        columnCount-- # subtract 1 for the row move

      column = column - columnCount
      @setScreenPosition({row, column}, clipDirection: 'backward')

  # Public: Moves the cursor right one screen column.
  #
  # * `columnCount` (optional) {Number} number of columns to move (default: 1)
  # * `options` (optional) {Object} with the following keys:
  #   * `moveToEndOfSelection` if true, move to the right of the selection if a
  #     selection exists.
  moveRight: (columnCount=1, {moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      @setScreenPosition(range.end)
    else
      {row, column} = @getScreenPosition()
      maxLines = @editor.getScreenLineCount()
      rowLength = @editor.lineLengthForScreenRow(row)
      columnsRemainingInLine = rowLength - column

      while columnCount > columnsRemainingInLine and row < maxLines - 1
        columnCount -= columnsRemainingInLine
        columnCount-- # subtract 1 for the row move

        column = 0
        rowLength = @editor.lineLengthForScreenRow(++row)
        columnsRemainingInLine = rowLength

      column = column + columnCount
      @setScreenPosition({row, column}, clipDirection: 'forward')

  # Public: Moves the cursor to the top of the buffer.
  moveToTop: ->
    @setBufferPosition([0, 0])

  # Public: Moves the cursor to the bottom of the buffer.
  moveToBottom: ->
    @setBufferPosition(@editor.getEofBufferPosition())

  # Public: Moves the cursor to the beginning of the line.
  moveToBeginningOfScreenLine: ->
    @setScreenPosition([@getScreenRow(), 0])

  # Public: Moves the cursor to the beginning of the buffer line.
  moveToBeginningOfLine: ->
    @setBufferPosition([@getBufferRow(), 0])

  # Public: Moves the cursor to the beginning of the first character in the
  # line.
  moveToFirstCharacterOfLine: ->
    screenRow = @getScreenRow()
    screenLineStart = @editor.clipScreenPosition([screenRow, 0], skipSoftWrapIndentation: true)
    screenLineEnd = [screenRow, Infinity]
    screenLineBufferRange = @editor.bufferRangeForScreenRange([screenLineStart, screenLineEnd])

    firstCharacterColumn = null
    @editor.scanInBufferRange /\S/, screenLineBufferRange, ({range, stop}) ->
      firstCharacterColumn = range.start.column
      stop()

    if firstCharacterColumn? and firstCharacterColumn isnt @getBufferColumn()
      targetBufferColumn = firstCharacterColumn
    else
      targetBufferColumn = screenLineBufferRange.start.column

    @setBufferPosition([screenLineBufferRange.start.row, targetBufferColumn])

  # Public: Moves the cursor to the end of the line.
  moveToEndOfScreenLine: ->
    @setScreenPosition([@getScreenRow(), Infinity])

  # Public: Moves the cursor to the end of the buffer line.
  moveToEndOfLine: ->
    @setBufferPosition([@getBufferRow(), Infinity])

  # Public: Moves the cursor to the beginning of the word.
  moveToBeginningOfWord: ->
    @setBufferPosition(@getBeginningOfCurrentWordBufferPosition())

  # Public: Moves the cursor to the end of the word.
  moveToEndOfWord: ->
    if position = @getEndOfCurrentWordBufferPosition()
      @setBufferPosition(position)

  # Public: Moves the cursor to the beginning of the next word.
  moveToBeginningOfNextWord: ->
    if position = @getBeginningOfNextWordBufferPosition()
      @setBufferPosition(position)

  # Public: Moves the cursor to the previous word boundary.
  moveToPreviousWordBoundary: ->
    if position = @getPreviousWordBoundaryBufferPosition()
      @setBufferPosition(position)

  # Public: Moves the cursor to the next word boundary.
  moveToNextWordBoundary: ->
    if position = @getNextWordBoundaryBufferPosition()
      @setBufferPosition(position)

  # Public: Moves the cursor to the previous subword boundary.
  moveToPreviousSubwordBoundary: ->
    options = {wordRegex: @subwordRegExp(backwards: true)}
    if position = @getPreviousWordBoundaryBufferPosition(options)
      @setBufferPosition(position)

  # Public: Moves the cursor to the next subword boundary.
  moveToNextSubwordBoundary: ->
    options = {wordRegex: @subwordRegExp()}
    if position = @getNextWordBoundaryBufferPosition(options)
      @setBufferPosition(position)

  # Public: Moves the cursor to the beginning of the buffer line, skipping all
  # whitespace.
  skipLeadingWhitespace: ->
    position = @getBufferPosition()
    scanRange = @getCurrentLineBufferRange()
    endOfLeadingWhitespace = null
    @editor.scanInBufferRange /^[ \t]*/, scanRange, ({range}) ->
      endOfLeadingWhitespace = range.end

    @setBufferPosition(endOfLeadingWhitespace) if endOfLeadingWhitespace.isGreaterThan(position)

  # Public: Moves the cursor to the beginning of the next paragraph
  moveToBeginningOfNextParagraph: ->
    if position = @getBeginningOfNextParagraphBufferPosition()
      @setBufferPosition(position)

  # Public: Moves the cursor to the beginning of the previous paragraph
  moveToBeginningOfPreviousParagraph: ->
    if position = @getBeginningOfPreviousParagraphBufferPosition()
      @setBufferPosition(position)

  ###
  Section: Local Positions and Ranges
  ###

  # Public: Returns buffer position of previous word boundary. It might be on
  # the current word, or the previous word.
  #
  # * `options` (optional) {Object} with the following keys:
  #   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  #      (default: {::wordRegExp})
  getPreviousWordBoundaryBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editor.buffer.previousNonBlankRow(currentBufferPosition.row)
    scanRange = [[previousNonBlankRow ? 0, 0], currentBufferPosition]

    beginningOfWordPosition = null
    @editor.backwardsScanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) ->
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

  # Public: Returns buffer position of the next word boundary. It might be on
  # the current word, or the previous word.
  #
  # * `options` (optional) {Object} with the following keys:
  #   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  #      (default: {::wordRegExp})
  getNextWordBoundaryBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    scanRange = [currentBufferPosition, @editor.getEofBufferPosition()]

    endOfWordPosition = null
    @editor.scanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) ->
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

  # Public: Retrieves the buffer position of where the current word starts.
  #
  # * `options` (optional) An {Object} with the following keys:
  #   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  #     (default: {::wordRegExp}).
  #   * `includeNonWordCharacters` A {Boolean} indicating whether to include
  #     non-word characters in the default word regex.
  #     Has no effect if wordRegex is set.
  #   * `allowPrevious` A {Boolean} indicating whether the beginning of the
  #     previous word can be returned.
  #
  # Returns a {Range}.
  getBeginningOfCurrentWordBufferPosition: (options = {}) ->
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editor.buffer.previousNonBlankRow(currentBufferPosition.row) ? 0
    scanRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = null
    @editor.backwardsScanInBufferRange (options.wordRegex ? @wordRegExp(options)), scanRange, ({range, matchText, stop}) ->
      # Ignore 'empty line' matches between '\r' and '\n'
      return if matchText is '' and range.start.column isnt 0

      if range.start.isLessThan(currentBufferPosition)
        if range.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
          beginningOfWordPosition = range.start
        stop()

    if beginningOfWordPosition?
      beginningOfWordPosition
    else if allowPrevious
      new Point(0, 0)
    else
      currentBufferPosition

  # Public: Retrieves the buffer position of where the current word ends.
  #
  # * `options` (optional) {Object} with the following keys:
  #   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  #      (default: {::wordRegExp})
  #   * `includeNonWordCharacters` A Boolean indicating whether to include
  #     non-word characters in the default word regex. Has no effect if
  #     wordRegex is set.
  #
  # Returns a {Range}.
  getEndOfCurrentWordBufferPosition: (options = {}) ->
    allowNext = options.allowNext ? true
    currentBufferPosition = @getBufferPosition()
    scanRange = [currentBufferPosition, @editor.getEofBufferPosition()]

    endOfWordPosition = null
    @editor.scanInBufferRange (options.wordRegex ? @wordRegExp(options)), scanRange, ({range, matchText, stop}) ->
      # Ignore 'empty line' matches between '\r' and '\n'
      return if matchText is '' and range.start.column isnt 0

      if range.end.isGreaterThan(currentBufferPosition)
        if allowNext or range.start.isLessThanOrEqual(currentBufferPosition)
          endOfWordPosition = range.end
        stop()

    endOfWordPosition ? currentBufferPosition

  # Public: Retrieves the buffer position of where the next word starts.
  #
  # * `options` (optional) {Object}
  #   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  #     (default: {::wordRegExp}).
  #
  # Returns a {Range}
  getBeginningOfNextWordBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    start = if @isInsideWord(options) then @getEndOfCurrentWordBufferPosition(options) else currentBufferPosition
    scanRange = [start, @editor.getEofBufferPosition()]

    beginningOfNextWordPosition = null
    @editor.scanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) ->
      beginningOfNextWordPosition = range.start
      stop()

    beginningOfNextWordPosition or currentBufferPosition

  # Public: Returns the buffer Range occupied by the word located under the cursor.
  #
  # * `options` (optional) {Object}
  #   * `wordRegex` A {RegExp} indicating what constitutes a "word"
  #     (default: {::wordRegExp}).
  getCurrentWordBufferRange: (options={}) ->
    startOptions = Object.assign(_.clone(options), allowPrevious: false)
    endOptions = Object.assign(_.clone(options), allowNext: false)
    new Range(@getBeginningOfCurrentWordBufferPosition(startOptions), @getEndOfCurrentWordBufferPosition(endOptions))

  # Public: Returns the buffer Range for the current line.
  #
  # * `options` (optional) {Object}
  #   * `includeNewline` A {Boolean} which controls whether the Range should
  #     include the newline.
  getCurrentLineBufferRange: (options) ->
    @editor.bufferRangeForBufferRow(@getBufferRow(), options)

  # Public: Retrieves the range for the current paragraph.
  #
  # A paragraph is defined as a block of text surrounded by empty lines or comments.
  #
  # Returns a {Range}.
  getCurrentParagraphBufferRange: ->
    @editor.languageMode.rowRangeForParagraphAtBufferRow(@getBufferRow())

  # Public: Returns the characters preceding the cursor in the current word.
  getCurrentWordPrefix: ->
    @editor.getTextInBufferRange([@getBeginningOfCurrentWordBufferPosition(), @getBufferPosition()])

  ###
  Section: Visibility
  ###

  # Public: Sets whether the cursor is visible.
  setVisible: (visible) ->
    if @visible isnt visible
      @visible = visible
      @emitter.emit 'did-change-visibility', @visible

  # Public: Returns the visibility of the cursor.
  isVisible: -> @visible

  updateVisibility: ->
    if @showCursorOnSelection
      @setVisible(true)
    else
      @setVisible(@marker.getBufferRange().isEmpty())

  ###
  Section: Comparing to another cursor
  ###

  # Public: Compare this cursor's buffer position to another cursor's buffer position.
  #
  # See {Point::compare} for more details.
  #
  # * `otherCursor`{Cursor} to compare against
  compare: (otherCursor) ->
    @getBufferPosition().compare(otherCursor.getBufferPosition())

  ###
  Section: Utilities
  ###

  # Public: Prevents this cursor from causing scrolling.
  clearAutoscroll: ->

  # Public: Deselects the current selection.
  clearSelection: (options) ->
    @selection?.clear(options)

  # Public: Get the RegExp used by the cursor to determine what a "word" is.
  #
  # * `options` (optional) {Object} with the following keys:
  #   * `includeNonWordCharacters` A {Boolean} indicating whether to include
  #     non-word characters in the regex. (default: true)
  #
  # Returns a {RegExp}.
  wordRegExp: (options) ->
    nonWordCharacters = _.escapeRegExp(@getNonWordCharacters())
    source = "^[\t ]*$|[^\\s#{nonWordCharacters}]+"
    if options?.includeNonWordCharacters ? true
      source += "|" + "[#{nonWordCharacters}]+"
    new RegExp(source, "g")

  # Public: Get the RegExp used by the cursor to determine what a "subword" is.
  #
  # * `options` (optional) {Object} with the following keys:
  #   * `backwards` A {Boolean} indicating whether to look forwards or backwards
  #     for the next subword. (default: false)
  #
  # Returns a {RegExp}.
  subwordRegExp: (options={}) ->
    nonWordCharacters = @getNonWordCharacters()
    lowercaseLetters = 'a-z\\u00DF-\\u00F6\\u00F8-\\u00FF'
    uppercaseLetters = 'A-Z\\u00C0-\\u00D6\\u00D8-\\u00DE'
    snakeCamelSegment = "[#{uppercaseLetters}]?[#{lowercaseLetters}]+"
    segments = [
      "^[\t ]+",
      "[\t ]+$",
      "[#{uppercaseLetters}]+(?![#{lowercaseLetters}])",
      "\\d+"
    ]
    if options.backwards
      segments.push("#{snakeCamelSegment}_*")
      segments.push("[#{_.escapeRegExp(nonWordCharacters)}]+\\s*")
    else
      segments.push("_*#{snakeCamelSegment}")
      segments.push("\\s*[#{_.escapeRegExp(nonWordCharacters)}]+")
    segments.push("_+")
    new RegExp(segments.join("|"), "g")

  ###
  Section: Private
  ###

  setShowCursorOnSelection: (value) ->
    if value isnt @showCursorOnSelection
      @showCursorOnSelection = value
      @updateVisibility()

  getNonWordCharacters: ->
    @editor.getNonWordCharacters(@getScopeDescriptor().getScopesArray())

  changePosition: (options, fn) ->
    @clearSelection(autoscroll: false)
    fn()
    @autoscroll() if options.autoscroll ? @isLastCursor()

  getScreenRange: ->
    {row, column} = @getScreenPosition()
    new Range(new Point(row, column), new Point(row, column + 1))

  autoscroll: (options) ->
    @editor.scrollToScreenRange(@getScreenRange(), options)

  getBeginningOfNextParagraphBufferPosition: ->
    start = @getBufferPosition()
    eof = @editor.getEofBufferPosition()
    scanRange = [start, eof]

    {row, column} = eof
    position = new Point(row, column - 1)

    @editor.scanInBufferRange EmptyLineRegExp, scanRange, ({range, stop}) ->
      position = range.start.traverse(Point(1, 0))
      stop() unless position.isEqual(start)
    position

  getBeginningOfPreviousParagraphBufferPosition: ->
    start = @getBufferPosition()

    {row, column} = start
    scanRange = [[row-1, column], [0, 0]]
    position = new Point(0, 0)
    @editor.backwardsScanInBufferRange EmptyLineRegExp, scanRange, ({range, stop}) ->
      position = range.start.traverse(Point(1, 0))
      stop() unless position.isEqual(start)
    position
