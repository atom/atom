{Point, Range} = require 'text-buffer'
{Model} = require 'theorist'
{Emitter} = require 'event-kit'
_ = require 'underscore-plus'
Grim = require 'grim'

# Extended: The `Cursor` class represents the little blinking line identifying
# where text can be inserted.
#
# Cursors belong to {TextEditor}s and have some metadata attached in the form
# of a {Marker}.
module.exports =
class Cursor extends Model
  screenPosition: null
  bufferPosition: null
  goalColumn: null
  visible: true
  needsAutoscroll: null

  # Instantiated by a {TextEditor}
  constructor: ({@editor, @marker, id}) ->
    @emitter = new Emitter

    @assignId(id)
    @updateVisibility()
    @marker.onDidChange (e) =>
      @updateVisibility()
      {oldHeadScreenPosition, newHeadScreenPosition} = e
      {oldHeadBufferPosition, newHeadBufferPosition} = e
      {textChanged} = e
      return if oldHeadScreenPosition.isEqual(newHeadScreenPosition)

      # Supports old editor view
      @needsAutoscroll ?= @isLastCursor() and !textChanged
      @autoscroll() if @editor.manageScrollPosition and @isLastCursor() and textChanged

      @goalColumn = null

      movedEvent =
        oldBufferPosition: oldHeadBufferPosition
        oldScreenPosition: oldHeadScreenPosition
        newBufferPosition: newHeadBufferPosition
        newScreenPosition: newHeadScreenPosition
        textChanged: textChanged
        cursor: this

      @emit 'moved', movedEvent
      @emitter.emit 'did-change-position', movedEvent
      @editor.cursorMoved(movedEvent)
    @marker.onDidDestroy =>
      @destroyed = true
      @editor.removeCursor(this)
      @emit 'destroyed'
      @emitter.emit 'did-destroy'
      @emitter.dispose()
    @needsAutoscroll = true

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

  on: (eventName) ->
    switch eventName
      when 'moved'
        Grim.deprecate("Use Cursor::onDidChangePosition instead")
      when 'destroyed'
        Grim.deprecate("Use Cursor::onDidDestroy instead")
      when 'destroyed'
        Grim.deprecate("Use Cursor::onDidDestroy instead")
      else
        Grim.deprecate("::on is no longer supported. Use the event subscription methods instead")
    super

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

  # Public: Returns the screen position of the cursor as an Array.
  getScreenPosition: ->
    @marker.getHeadScreenPosition()

  # Public: Moves a cursor to a given buffer position.
  #
  # * `bufferPosition` {Array} of two numbers: the buffer row, and the buffer column.
  # * `options` (optional) {Object} with the following keys:
  #   * `autoscroll` A Boolean which, if `true`, scrolls the {TextEditor} to wherever
  #     the cursor moves to.
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
    @getBufferPosition().column == 0

  # Public: Returns whether the cursor is on the line return character.
  isAtEndOfLine: ->
    @getBufferPosition().isEqual(@getCurrentLineBufferRange().end)

  ###
  Section: Cursor Position Details
  ###

  # Public: Returns the underlying {Marker} for the cursor.
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

    nonWordCharacters = atom.config.get('editor.nonWordCharacters', scope: @getScopeDescriptor()).split('')
    _.contains(nonWordCharacters, before) isnt _.contains(nonWordCharacters, after)

  # Public: Returns whether this cursor is between a word's start and end.
  isInsideWord: ->
    {row, column} = @getBufferPosition()
    range = [[row, column], [row, Infinity]]
    @editor.getTextInBufferRange(range).search(@wordRegExp()) == 0

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
  getScopes: ->
    Grim.deprecate 'Use Cursor::getScopeDescriptor() instead'
    @getScopeDescriptor().getScopesArray()

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
    this == @editor.getLastCursor()

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
      { row, column } = range.start
    else
      { row, column } = @getScreenPosition()

    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - rowCount, column: column})
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
      { row, column } = range.end
    else
      { row, column } = @getScreenPosition()

    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + rowCount, column: column})
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
        column = @editor.lineTextForScreenRow(--row).length
        columnCount-- # subtract 1 for the row move

      column = column - columnCount
      @setScreenPosition({row, column})

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
      { row, column } = @getScreenPosition()
      maxLines = @editor.getScreenLineCount()
      rowLength = @editor.lineTextForScreenRow(row).length
      columnsRemainingInLine = rowLength - column

      while columnCount > columnsRemainingInLine and row < maxLines - 1
        columnCount -= columnsRemainingInLine
        columnCount-- # subtract 1 for the row move

        column = 0
        rowLength = @editor.lineTextForScreenRow(++row).length
        columnsRemainingInLine = rowLength

      column = column + columnCount
      @setScreenPosition({row, column}, skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true)

  # Public: Moves the cursor to the top of the buffer.
  moveToTop: ->
    @setBufferPosition([0,0])

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
    lineBufferRange = @editor.bufferRangeForScreenRange([[screenRow, 0], [screenRow, Infinity]])

    firstCharacterColumn = null
    @editor.scanInBufferRange /\S/, lineBufferRange, ({range, stop}) ->
      firstCharacterColumn = range.start.column
      stop()

    if firstCharacterColumn? and firstCharacterColumn isnt @getBufferColumn()
      targetBufferColumn = firstCharacterColumn
    else
      targetBufferColumn = lineBufferRange.start.column

    @setBufferPosition([lineBufferRange.start.row, targetBufferColumn])

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
    scanRange = [[previousNonBlankRow, 0], currentBufferPosition]

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

  getMoveNextWordBoundaryBufferPosition: (options) ->
    Grim.deprecate 'Use `::getNextWordBoundaryBufferPosition(options)` instead'
    @getNextWordBoundaryBufferPosition(options)

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
    @editor.backwardsScanInBufferRange (options.wordRegex ? @wordRegExp(options)), scanRange, ({range, stop}) ->
      if range.end.isGreaterThanOrEqual(currentBufferPosition) or allowPrevious
        beginningOfWordPosition = range.start
      if not beginningOfWordPosition?.isEqual(currentBufferPosition)
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
    @editor.scanInBufferRange (options.wordRegex ? @wordRegExp(options)), scanRange, ({range, stop}) ->
      if range.start.isLessThanOrEqual(currentBufferPosition) or allowNext
        endOfWordPosition = range.end
      if not endOfWordPosition?.isEqual(currentBufferPosition)
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
    start = if @isInsideWord() then @getEndOfCurrentWordBufferPosition() else currentBufferPosition
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
    startOptions = _.extend(_.clone(options), allowPrevious: false)
    endOptions = _.extend(_.clone(options), allowNext: false)
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
  # A paragraph is defined as a block of text surrounded by empty lines.
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

  # Public: If the marker range is empty, the cursor is marked as being visible.
  updateVisibility: ->
    @setVisible(@marker.getBufferRange().isEmpty())

  # Public: Sets whether the cursor is visible.
  setVisible: (visible) ->
    if @visible != visible
      @visible = visible
      @needsAutoscroll ?= true if @visible and @isLastCursor()
      @emit 'visibility-changed', @visible
      @emitter.emit 'did-change-visibility', @visible

  # Public: Returns the visibility of the cursor.
  isVisible: -> @visible

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
    @needsAutoscroll = null

  # Public: Deselects the current selection.
  clearSelection: ->
    @selection?.clear()

  # Public: Get the RegExp used by the cursor to determine what a "word" is.
  #
  # * `options` (optional) {Object} with the following keys:
  #   * `includeNonWordCharacters` A {Boolean} indicating whether to include
  #     non-word characters in the regex. (default: true)
  #
  # Returns a {RegExp}.
  wordRegExp: ({includeNonWordCharacters}={}) ->
    includeNonWordCharacters ?= true
    nonWordCharacters = atom.config.get('editor.nonWordCharacters', scope: @getScopeDescriptor())
    segments = ["^[\t ]*$"]
    segments.push("[^\\s#{_.escapeRegExp(nonWordCharacters)}]+")
    if includeNonWordCharacters
      segments.push("[#{_.escapeRegExp(nonWordCharacters)}]+")
    new RegExp(segments.join("|"), "g")

  ###
  Section: Private
  ###

  changePosition: (options, fn) ->
    @clearSelection()
    @needsAutoscroll = options.autoscroll ? @isLastCursor()
    fn()
    if @needsAutoscroll
      @emit 'autoscrolled' # Support legacy editor
      @autoscroll() if @needsAutoscroll and @editor.manageScrollPosition # Support react editor view

  getPixelRect: ->
    @editor.pixelRectForScreenRange(@getScreenRange())

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

    @editor.scanInBufferRange /^\n*$/g, scanRange, ({range, stop}) ->
      if !range.start.isEqual(start)
        position = range.start
        stop()
    @editor.screenPositionForBufferPosition(position)

  getBeginningOfPreviousParagraphBufferPosition: ->
    start = @getBufferPosition()

    {row, column} = start
    scanRange = [[row-1, column], [0,0]]
    position = new Point(0, 0)
    zero = new Point(0,0)
    @editor.backwardsScanInBufferRange /^\n*$/g, scanRange, ({range, stop}) ->
      if !range.start.isEqual(zero)
        position = range.start
        stop()
    @editor.screenPositionForBufferPosition(position)
