{Point, Range} = require 'text-buffer'
{Model} = require 'theorist'
_ = require 'underscore-plus'

# Public: The `Cursor` class represents the little blinking line identifying
# where text can be inserted.
#
# Cursors belong to {Editor}s and have some metadata attached in the form
# of a {Marker}.
module.exports =
class Cursor extends Model
  screenPosition: null
  bufferPosition: null
  goalColumn: null
  visible: true
  needsAutoscroll: null

  # Instantiated by an {Editor}
  constructor: ({@editor, @marker, id}) ->
    @assignId(id)
    @updateVisibility()
    @marker.on 'changed', (e) =>
      @updateVisibility()
      {oldHeadScreenPosition, newHeadScreenPosition} = e
      {oldHeadBufferPosition, newHeadBufferPosition} = e
      {textChanged} = e
      return if oldHeadScreenPosition.isEqual(newHeadScreenPosition)

      # Supports old editor view
      @needsAutoscroll ?= @isLastCursor() and !textChanged

      # Supports react editor view
      @autoscroll() if @needsAutoscroll and @editor.manageScrollPosition

      @goalColumn = null

      movedEvent =
        oldBufferPosition: oldHeadBufferPosition
        oldScreenPosition: oldHeadScreenPosition
        newBufferPosition: newHeadBufferPosition
        newScreenPosition: newHeadScreenPosition
        textChanged: textChanged

      @emit 'moved', movedEvent
      @editor.cursorMoved(movedEvent)
    @marker.on 'destroyed', =>
      @destroyed = true
      @editor.removeCursor(this)
      @emit 'destroyed'
    @needsAutoscroll = true

  destroy: ->
    @marker.destroy()

  changePosition: (options, fn) ->
    @clearSelection()
    @needsAutoscroll = options.autoscroll ? @isLastCursor()
    unless fn()
      @emit 'autoscrolled' if @needsAutoscroll

  getPixelRect: ->
    @editor.pixelRectForScreenRange(@getScreenRange())

  # Public: Moves a cursor to a given screen position.
  #
  # screenPosition - An {Array} of two numbers: the screen row, and the screen
  #                  column.
  # options - An {Object} with the following keys:
  #   :autoscroll - A Boolean which, if `true`, scrolls the {Editor} to wherever
  #                 the cursor moves to.
  setScreenPosition: (screenPosition, options={}) ->
    @changePosition options, =>
      @marker.setHeadScreenPosition(screenPosition, options)

  # Public: Returns the screen position of the cursor as an Array.
  getScreenPosition: ->
    @marker.getHeadScreenPosition()

  getScreenRange: ->
    {row, column} = @getScreenPosition()
    new Range(new Point(row, column), new Point(row, column + 1))

  # Public: Moves a cursor to a given buffer position.
  #
  # bufferPosition - An {Array} of two numbers: the buffer row, and the buffer
  #                  column.
  # options - An {Object} with the following keys:
  #   :autoscroll - A Boolean which, if `true`, scrolls the {Editor} to wherever
  #                 the cursor moves to.
  setBufferPosition: (bufferPosition, options={}) ->
    @changePosition options, =>
      @marker.setHeadBufferPosition(bufferPosition, options)

  # Public: Returns the current buffer position as an Array.
  getBufferPosition: ->
    @marker.getHeadBufferPosition()

  autoscroll: ->
    @editor.scrollToScreenRange(@getScreenRange())

  # Public: If the marker range is empty, the cursor is marked as being visible.
  updateVisibility: ->
    @setVisible(@marker.getBufferRange().isEmpty())

  # Public: Sets whether the cursor is visible.
  setVisible: (visible) ->
    if @visible != visible
      @visible = visible
      @needsAutoscroll ?= true if @visible and @isLastCursor()
      @emit 'visibility-changed', @visible

  # Public: Returns the visibility of the cursor.
  isVisible: -> @visible

  # Public: Get the RegExp used by the cursor to determine what a "word" is.
  #
  # options: An {Object} with the following keys:
  #   :includeNonWordCharacters - A {Boolean} indicating whether to include
  #                               non-word characters in the regex.
  #
  # Returns a {RegExp}.
  wordRegExp: ({includeNonWordCharacters}={})->
    includeNonWordCharacters ?= true
    nonWordCharacters = atom.config.get('editor.nonWordCharacters')
    segments = ["^[\t ]*$"]
    segments.push("[^\\s#{_.escapeRegExp(nonWordCharacters)}]+")
    if includeNonWordCharacters
      segments.push("[#{_.escapeRegExp(nonWordCharacters)}]+")
    new RegExp(segments.join("|"), "g")

  # Public: Identifies if this cursor is the last in the {Editor}.
  #
  # "Last" is defined as the most recently added cursor.
  #
  # Returns a {Boolean}.
  isLastCursor: ->
    this == @editor.getCursor()

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

    nonWordCharacters = atom.config.get('editor.nonWordCharacters').split('')
    _.contains(nonWordCharacters, before) isnt _.contains(nonWordCharacters, after)

  # Public: Returns whether this cursor is between a word's start and end.
  isInsideWord: ->
    {row, column} = @getBufferPosition()
    range = [[row, column], [row, Infinity]]
    @editor.getTextInBufferRange(range).search(@wordRegExp()) == 0

  # Public: Prevents this cursor from causing scrolling.
  clearAutoscroll: ->
    @needsAutoscroll = null

  # Public: Deselects the current selection.
  clearSelection: ->
    @selection?.clear()

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
    @editor.lineForBufferRow(@getBufferRow())

  # Public: Moves the cursor up one screen row.
  moveUp: (rowCount = 1, {moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      { row, column } = range.start
    else
      { row, column } = @getScreenPosition()

    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - rowCount, column: column})
    @goalColumn = column

  # Public: Moves the cursor down one screen row.
  moveDown: (rowCount = 1, {moveToEndOfSelection}={}) ->
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
  # options - An {Object} with the following keys:
  #   :moveToEndOfSelection - if true, move to the left of the selection if a
  #                           selection exists.
  moveLeft: ({moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      @setScreenPosition(range.start)
    else
      {row, column} = @getScreenPosition()
      [row, column] = if column > 0 then [row, column - 1] else [row - 1, Infinity]
      @setScreenPosition({row, column})

  # Public: Moves the cursor right one screen column.
  #
  # options - An {Object} with the following keys:
  #   :moveToEndOfSelection - if true, move to the right of the selection if a
  #                           selection exists.
  moveRight: ({moveToEndOfSelection}={}) ->
    range = @marker.getScreenRange()
    if moveToEndOfSelection and not range.isEmpty()
      @setScreenPosition(range.end)
    else
      { row, column } = @getScreenPosition()
      @setScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true)

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
    {row, column} = @getScreenPosition()
    screenline = @editor.lineForScreenRow(row)

    goalColumn = screenline.text.search(/\S/)
    goalColumn = 0 if goalColumn == column or goalColumn == -1
    @setScreenPosition([row, goalColumn])

  # Public: Moves the cursor to the beginning of the buffer line, skipping all
  # whitespace.
  skipLeadingWhitespace: ->
    position = @getBufferPosition()
    scanRange = @getCurrentLineBufferRange()
    endOfLeadingWhitespace = null
    @editor.scanInBufferRange /^[ \t]*/, scanRange, ({range}) =>
      endOfLeadingWhitespace = range.end

    @setBufferPosition(endOfLeadingWhitespace) if endOfLeadingWhitespace.isGreaterThan(position)

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
    if position = @getMoveNextWordBoundaryBufferPosition()
      @setBufferPosition(position)

  # Public: Retrieves the buffer position of where the current word starts.
  #
  # options - An {Object} with the following keys:
  #   :wordRegex - A {RegExp} indicating what constitutes a "word"
  #                (default: {::wordRegExp}).
  #   :includeNonWordCharacters - A {Boolean} indicating whether to include
  #                               non-word characters in the default word regex.
  #                               Has no effect if wordRegex is set.
  #   :allowPrevious - A {Boolean} indicating whether the beginning of the
  #                    previous word can be returned.
  #
  # Returns a {Range}.
  getBeginningOfCurrentWordBufferPosition: (options = {}) ->
    allowPrevious = options.allowPrevious ? true
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editor.buffer.previousNonBlankRow(currentBufferPosition.row) ? 0
    scanRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = null
    @editor.backwardsScanInBufferRange (options.wordRegex ? @wordRegExp(options)), scanRange, ({range, stop}) =>
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

  # Public: Retrieves buffer position of previous word boundary. It might be on
  # the current word, or the previous word.
  getPreviousWordBoundaryBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    previousNonBlankRow = @editor.buffer.previousNonBlankRow(currentBufferPosition.row)
    scanRange = [[previousNonBlankRow, 0], currentBufferPosition]

    beginningOfWordPosition = null
    @editor.backwardsScanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
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

  # Public: Retrieves buffer position of the next word boundary. It might be on
  # the current word, or the previous word.
  getMoveNextWordBoundaryBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    scanRange = [currentBufferPosition, @editor.getEofBufferPosition()]

    endOfWordPosition = null
    @editor.scanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
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

  # Public: Retrieves the buffer position of where the current word ends.
  #
  # options - An {Object} with the following keys:
  #   :wordRegex - A {RegExp} indicating what constitutes a "word"
  #                (default: {::wordRegExp})
  #   :includeNonWordCharacters - A Boolean indicating whether to include
  #                               non-word characters in the default word regex.
  #                               Has no effect if wordRegex is set.
  #
  # Returns a {Range}.
  getEndOfCurrentWordBufferPosition: (options = {}) ->
    allowNext = options.allowNext ? true
    currentBufferPosition = @getBufferPosition()
    scanRange = [currentBufferPosition, @editor.getEofBufferPosition()]

    endOfWordPosition = null
    @editor.scanInBufferRange (options.wordRegex ? @wordRegExp(options)), scanRange, ({range, stop}) =>
      if range.start.isLessThanOrEqual(currentBufferPosition) or allowNext
        endOfWordPosition = range.end
      if not endOfWordPosition?.isEqual(currentBufferPosition)
        stop()

    endOfWordPosition ? currentBufferPosition

  # Public: Retrieves the buffer position of where the next word starts.
  #
  # options -
  #   :wordRegex - A {RegExp} indicating what constitutes a "word"
  #                (default: {::wordRegExp}).
  #
  # Returns a {Range}.
  getBeginningOfNextWordBufferPosition: (options = {}) ->
    currentBufferPosition = @getBufferPosition()
    start = if @isInsideWord() then @getEndOfCurrentWordBufferPosition() else currentBufferPosition
    scanRange = [start, @editor.getEofBufferPosition()]

    beginningOfNextWordPosition = null
    @editor.scanInBufferRange (options.wordRegex ? @wordRegExp()), scanRange, ({range, stop}) =>
      beginningOfNextWordPosition = range.start
      stop()

    beginningOfNextWordPosition or currentBufferPosition

  # Public: Returns the buffer Range occupied by the word located under the cursor.
  #
  # options -
  #   :wordRegex - A {RegExp} indicating what constitutes a "word"
  #                (default: {::wordRegExp}).
  getCurrentWordBufferRange: (options={}) ->
    startOptions = _.extend(_.clone(options), allowPrevious: false)
    endOptions = _.extend(_.clone(options), allowNext: false)
    new Range(@getBeginningOfCurrentWordBufferPosition(startOptions), @getEndOfCurrentWordBufferPosition(endOptions))

  # Public: Returns the buffer Range for the current line.
  #
  # options -
  #   :includeNewline: - A {Boolean} which controls whether the Range should
  #                      include the newline.
  getCurrentLineBufferRange: (options) ->
    @editor.bufferRangeForBufferRow(@getBufferRow(), options)

  # Public: Moves the cursor to the beginning of the next paragraph
  moveToBeginningOfNextParagraph: ->
    if position = @getBeginningOfNextParagraphBufferPosition()
      @setBufferPosition(position)

  # Public: Moves the cursor to the beginning of the previous paragraph
  moveToBeginningOfPreviousParagraph: ->
    if position = @getBeginningOfPreviousParagraphBufferPosition()
      @setBufferPosition(position)

  getBeginningOfNextParagraphBufferPosition: (editor) ->
    start = @getBufferPosition()
    eof = @editor.getEofBufferPosition()
    scanRange = [start, eof]

    {row, column} = eof
    position = new Point(row, column - 1)

    @editor.scanInBufferRange /^\n*$/g, scanRange, ({range, stop}) =>
      if !range.start.isEqual(start)
        position = range.start
        stop()
    @editor.screenPositionForBufferPosition(position)

  getBeginningOfPreviousParagraphBufferPosition: (editor) ->
    start = @editor.getCursorBufferPosition()

    {row, column} = start
    scanRange = [[row-1, column], [0,0]]
    position = new Point(0, 0)
    zero = new Point(0,0)
    @editor.backwardsScanInBufferRange /^\n*$/g, scanRange, ({range, stop}) =>
      if !range.start.isEqual(zero)
        position = range.start
        stop()
    @editor.screenPositionForBufferPosition(position)

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

  # Public: Returns whether the cursor is at the start of a line.
  isAtBeginningOfLine: ->
    @getBufferPosition().column == 0

  # Public: Returns the indentation level of the current line.
  getIndentLevel: ->
    if @editor.getSoftTabs()
      @getBufferColumn() / @editor.getTabLength()
    else
      @getBufferColumn()

  # Public: Returns whether the cursor is on the line return character.
  isAtEndOfLine: ->
    @getBufferPosition().isEqual(@getCurrentLineBufferRange().end)

  # Public: Retrieves the grammar's token scopes for the line.
  #
  # Returns an {Array} of {String}s.
  getScopes: ->
    @editor.scopesForBufferPosition(@getBufferPosition())

  # Public: Returns true if this cursor has no non-whitespace characters before
  # its current position.
  hasPrecedingCharactersOnLine: ->
    bufferPosition = @getBufferPosition()
    line = @editor.lineForBufferRow(bufferPosition.row)
    firstCharacterColumn = line.search(/\S/)

    if firstCharacterColumn is -1
      false
    else
      bufferPosition.column > firstCharacterColumn
