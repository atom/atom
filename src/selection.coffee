{Range} = require 'telepath'
{EventEmitter} = require 'emissary'
_ = require './underscore-extensions'

# Public: Represents a selection in the {EditSession}.
module.exports =
class Selection
  _.extend @prototype, EventEmitter

  cursor: null
  marker: null
  editSession: null
  initialScreenRange: null
  wordwise: false
  needsAutoscroll: null


  # Private:
  constructor: ({@cursor, @marker, @editSession}) ->
    @cursor.selection = this
    @marker.on 'changed', => @screenRangeChanged()
    @marker.on 'destroyed', =>
      @destroyed = true
      @editSession.removeSelection(this)
      @emit 'destroyed' unless @editSession.destroyed

  # Private:
  destroy: ->
    @marker.destroy()

  # Private:
  finalize: ->
    @initialScreenRange = null unless @initialScreenRange?.isEqual(@getScreenRange())
    if @isEmpty()
      @wordwise = false
      @linewise = false

  # Private:
  clearAutoscroll: ->
    @needsAutoscroll = null

  # Public: Determines if the selection contains anything.
  isEmpty: ->
    @getBufferRange().isEmpty()

  # Public: Determines if the ending position of a marker is greater than the
  # starting position.
  #
  # This can happen when, for example, you highlight text "up" in a {TextBuffer}.
  isReversed: ->
    @marker.isReversed()

  # Public: Returns whether the selection is a single line or not.
  isSingleScreenLine: ->
    @getScreenRange().isSingleLine()

  # Public: Returns the screen {Range} for the selection.
  getScreenRange: ->
    @marker.getScreenRange()

  # Public: Modifies the screen range for the selection.
  #
  # * screenRange:
  #   The new {Range} to use
  # * options:
  #   + A hash of options matching those found in {.setBufferRange}
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@editSession.bufferRangeForScreenRange(screenRange), options)

  # Public: Returns the buffer {Range} for the selection.
  getBufferRange: ->
    @marker.getBufferRange()

  # Public: Modifies the buffer {Range} for the selection.
  #
  # * screenRange:
  #   The new {Range} to select
  # * options
  #    + preserveFolds:
  #      if `true`, the fold settings are preserved after the selection moves
  #    + autoscroll:
  #      if `true`, the {EditSession} scrolls to the new selection
  setBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    @needsAutoscroll = options.autoscroll
    options.isReversed ?= @isReversed()
    @editSession.destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
    @modifySelection =>
      @cursor.needsAutoscroll = false if options.autoscroll?
      @marker.setBufferRange(bufferRange, options)

  # Public: Returns the starting and ending buffer rows the selection is
  # highlighting.
  #
  # Returns an {Array} of two {Number}s: the starting row, and the ending row.
  getBufferRowRange: ->
    range = @getBufferRange()
    start = range.start.row
    end = range.end.row
    end = Math.max(start, end - 1) if range.end.column == 0
    [start, end]

  # Public: Returns the text in the selection.
  getText: ->
    @editSession.buffer.getTextInRange(@getBufferRange())

  # Public: Clears the selection, moving the marker to the head.
  clear: ->
    @marker.setAttributes(goalBufferRange: null)
    @marker.clearTail() unless @retainSelection

  # Public: Modifies the selection to encompass the current word.
  #
  # Returns a {Range}.
  selectWord: ->
    options = {}
    options.wordRegex = /[\t ]*/ if @cursor.isSurroundedByWhitespace()
    if @cursor.isBetweenWordAndNonWord()
      options.includeNonWordCharacters = false

    @setBufferRange(@cursor.getCurrentWordBufferRange(options))
    @wordwise = true
    @initialScreenRange = @getScreenRange()

  # Public: Expands the newest selection to include the entire word on which
  # the cursors rests.
  expandOverWord: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentWordBufferRange()))

  # Public: Selects an entire line in the buffer.
  #
  # * row:
  #   The line Number to select (default: the row of the cursor)
  selectLine: (row=@cursor.getBufferPosition().row) ->
    range = @editSession.bufferRangeForBufferRow(row, includeNewline: true)
    @setBufferRange(range)
    @linewise = true
    @wordwise = false
    @initialScreenRange = @getScreenRange()

  # Public: Expands the newest selection to include the entire line on which
  # the cursor currently rests.
  #
  # It also includes the newline character.
  expandOverLine: ->
    range = @getBufferRange().union(@cursor.getCurrentLineBufferRange(includeNewline: true))
    @setBufferRange(range)

  # Public: Selects the text from the current cursor position to a given screen
  # position.
  #
  # * position:
  #   An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    @modifySelection =>
      if @initialScreenRange
        if position.isLessThan(@initialScreenRange.start)
          @marker.setScreenRange([position, @initialScreenRange.end], isReversed: true)
        else
          @marker.setScreenRange([@initialScreenRange.start, position])
      else
        @cursor.setScreenPosition(position)

      if @linewise
        @expandOverLine()
      else if @wordwise
        @expandOverWord()

  # Public: Selects the text from the current cursor position to a given buffer
  # position.
  #
  # * position:
  #   An instance of {Point}, with a given `row` and `column`.
  selectToBufferPosition: (position) ->
    @modifySelection => @cursor.setBufferPosition(position)

  # Public: Selects the text one position right of the cursor.
  selectRight: ->
    @modifySelection => @cursor.moveRight()

  # Public: Selects the text one position left of the cursor.
  selectLeft: ->
    @modifySelection => @cursor.moveLeft()

  # Public: Selects all the text one position above the cursor.
  selectUp: ->
    @modifySelection => @cursor.moveUp()

  # Public: Selects all the text one position below the cursor.
  selectDown: ->
    @modifySelection => @cursor.moveDown()

  # Public: Selects all the text from the current cursor position to the top of
  # the buffer.
  selectToTop: ->
    @modifySelection => @cursor.moveToTop()

  # Public: Selects all the text from the current cursor position to the bottom
  # of the buffer.
  selectToBottom: ->
    @modifySelection => @cursor.moveToBottom()

  # Public: Selects all the text in the buffer.
  selectAll: ->
    @setBufferRange(@editSession.buffer.getRange(), autoscroll: false)

  # Public: Selects all the text from the current cursor position to the
  # beginning of the line.
  selectToBeginningOfLine: ->
    @modifySelection => @cursor.moveToBeginningOfLine()

  # Public: Selects all the text from the current cursor position to the first
  # character of the line.
  selectToFirstCharacterOfLine: ->
    @modifySelection => @cursor.moveToFirstCharacterOfLine()

  # Public: Selects all the text from the current cursor position to the end of
  # the line.
  selectToEndOfLine: ->
    @modifySelection => @cursor.moveToEndOfLine()

  # Public: Selects all the text from the current cursor position to the
  # beginning of the word.
  selectToBeginningOfWord: ->
    @modifySelection => @cursor.moveToBeginningOfWord()

  # Public: Selects all the text from the current cursor position to the end of
  # the word.
  selectToEndOfWord: ->
    @modifySelection => @cursor.moveToEndOfWord()

  # Public: Selects all the text from the current cursor position to the
  # beginning of the next word.
  selectToBeginningOfNextWord: ->
    @modifySelection => @cursor.moveToBeginningOfNextWord()

  # Public: Selects text to the previous word boundary.
  selectToPreviousWordBoundary: ->
    @modifySelection => @cursor.moveToPreviousWordBoundary()

  # Public: Selects text to the next word boundary.
  selectToNextWordBoundary: ->
    @modifySelection => @cursor.moveToNextWordBoundary()

  # Public: Moves the selection down one row.
  addSelectionBelow: ->
    range = (@getGoalBufferRange() ? @getBufferRange()).copy()
    nextRow = range.end.row + 1

    for row in [nextRow..@editSession.getLastBufferRow()]
      range.start.row = row
      range.end.row = row
      clippedRange = @editSession.clipBufferRange(range)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      @editSession.addSelectionForBufferRange(range, goalBufferRange: range)
      break

  # Public:
  #
  # FIXME: I have no idea what this does.
  getGoalBufferRange: ->
    @marker.getAttributes().goalBufferRange

  # Public: Moves the selection up one row.
  addSelectionAbove: ->
    range = (@getGoalBufferRange() ? @getBufferRange()).copy()
    previousRow = range.end.row - 1

    for row in [previousRow..0]
      range.start.row = row
      range.end.row = row
      clippedRange = @editSession.clipBufferRange(range)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      @editSession.addSelectionForBufferRange(range, goalBufferRange: range)
      break

  # Public: Replaces text at the current selection.
  #
  # * text:
  #   A {String} representing the text to add
  # * options
  #    + select:
  #      if `true`, selects the newly added text
  #    + autoIndent:
  #      if `true`, indents all inserted text appropriately
  #    + autoIndentNewline:
  #      if `true`, indent newline appropriately
  #    + autoDecreaseIndent:
  #      if `true`, decreases indent level appropriately (for example, when a
  #      closing bracket is inserted)
  #    + skipUndo:
  #      if `true`, skips the undo stack for this operation.
  insertText: (text, options={}) ->
    oldBufferRange = @getBufferRange()
    @editSession.destroyFoldsContainingBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    @clear()
    @cursor.needsAutoscroll = @cursor.isLastCursor()

    if options.indentBasis? and not options.autoIndent
      text = @normalizeIndents(text, options.indentBasis)

    newBufferRange = @editSession.buffer.change(oldBufferRange, text, skipUndo: options.skipUndo)
    if options.select
      @setBufferRange(newBufferRange, isReversed: wasReversed)
    else
      @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed

    if options.autoIndent
      @editSession.autoIndentBufferRow(row) for row in newBufferRange.getRows()
    else if options.autoIndentNewline and text == '\n'
      @editSession.autoIndentBufferRow(newBufferRange.end.row)
    else if options.autoDecreaseIndent and /\S/.test text
      @editSession.autoDecreaseIndentForBufferRow(newBufferRange.start.row)

    newBufferRange

  # Public: Indents the given text to the suggested level based on the grammar.
  #
  # * text:
  #   The string to indent within the selection.
  # * indentBasis:
  #   The beginning indent level.
  normalizeIndents: (text, indentBasis) ->
    textPrecedingCursor = @cursor.getCurrentBufferLine()[0...@cursor.getBufferColumn()]
    isCursorInsideExistingLine = /\S/.test(textPrecedingCursor)

    lines = text.split('\n')
    firstLineIndentLevel = @editSession.indentLevelForLine(lines[0])
    if isCursorInsideExistingLine
      minimumIndentLevel = @editSession.indentationForBufferRow(@cursor.getBufferRow())
    else
      minimumIndentLevel = @cursor.getIndentLevel()

    normalizedLines = []
    for line, i in lines
      if i == 0
        indentLevel = 0
      else if line == '' # remove all indentation from empty lines
        indentLevel = 0
      else
        lineIndentLevel = @editSession.indentLevelForLine(lines[i])
        indentLevel = minimumIndentLevel + (lineIndentLevel - indentBasis)

      normalizedLines.push(@setIndentationForLine(line, indentLevel))

    normalizedLines.join('\n')

  # Public: Indents the selection.
  #
  # * options - A hash with one key,
  #    + autoIndent:
  #      If `true`, the indentation is performed appropriately. Otherwise,
  #      {EditSession.getTabText} is used
  indent: ({ autoIndent }={})->
    { row, column } = @cursor.getBufferPosition()

    if @isEmpty()
      @cursor.skipLeadingWhitespace()
      desiredIndent = @editSession.suggestedIndentForBufferRow(row)
      delta = desiredIndent - @cursor.getIndentLevel()

      if autoIndent and delta > 0
        @insertText(@editSession.buildIndentString(delta))
      else
        @insertText(@editSession.getTabText())
    else
      @indentSelectedRows()

  # Public: If the selection spans multiple rows, indent all of them.
  indentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    for row in [start..end]
      @editSession.buffer.insert([row, 0], @editSession.getTabText()) unless @editSession.buffer.lineLengthForRow(row) == 0

  # Public: ?
  setIndentationForLine: (line, indentLevel) ->
    desiredIndentLevel = Math.max(0, indentLevel)
    desiredIndentString = @editSession.buildIndentString(desiredIndentLevel)
    line.replace(/^[\t ]*/, desiredIndentString)

  # Public: Removes the first character before the selection if the selection
  # is empty otherwise it deletes the selection.
  backspace: ->
    @selectLeft() if @isEmpty() and not @editSession.isFoldedAtScreenRow(@cursor.getScreenRow())
    @deleteSelectedText()

  # Public: Removes from the start of the selection to the beginning of the
  # current word if the selection is empty otherwise it deletes the selection.
  backspaceToBeginningOfWord: ->
    @selectToBeginningOfWord() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes from the beginning of the line which the selection begins on
  # all the way through to the end of the selection.
  backspaceToBeginningOfLine: ->
    if @isEmpty() and @cursor.isAtBeginningOfLine()
      @selectLeft()
    else
      @selectToBeginningOfLine()
    @deleteSelectedText()

  # Public: Removes the selection or the next character after the start of the
  # selection if the selection is empty.
  delete: ->
    if @isEmpty()
      if @cursor.isAtEndOfLine() and fold = @editSession.largestFoldStartingAtScreenRow(@cursor.getScreenRow() + 1)
        @selectToBufferPosition(fold.getBufferRange().end)
      else
        @selectRight()
    @deleteSelectedText()

  # Public: Removes the selection or all characters from the start of the
  # selection to the end of the current word if nothing is selected.
  deleteToEndOfWord: ->
    @selectToEndOfWord() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes only the selected text.
  deleteSelectedText: ->
    bufferRange = @getBufferRange()
    if bufferRange.isEmpty() and fold = @editSession.largestFoldContainingBufferRow(bufferRange.start.row)
      bufferRange = bufferRange.union(fold.getBufferRange(includeNewline: true))
    @editSession.buffer.delete(bufferRange) unless bufferRange.isEmpty()
    @cursor?.setBufferPosition(bufferRange.start)

  # Public: Removes the line at the beginning of the selection if the selection
  # is empty unless the selection spans multiple lines in which case all lines
  # are removed.
  deleteLine: ->
    if @isEmpty()
      start = @cursor.getScreenRow()
      range = @editSession.bufferRowsForScreenRows(start, start + 1)
      if range[1] > range[0]
        @editSession.buffer.deleteRows(range[0], range[1] - 1)
      else
        @editSession.buffer.deleteRow(range[0])
    else
      range = @getBufferRange()
      start = range.start.row
      end = range.end.row
      if end isnt @editSession.buffer.getLastRow() and range.end.column is 0
        end--
      @editSession.buffer.deleteRows(start, end)

  # Public: Joins the current line with the one below it.
  #
  # If there selection spans more than one line, all the lines are joined together.
  joinLine: ->
    selectedRange = @getBufferRange()
    if selectedRange.isEmpty()
      return if selectedRange.start.row is @editSession.buffer.getLastRow()
    else
      joinMarker = @editSession.markBufferRange(selectedRange, invalidationStrategy: 'never')

    rowCount = Math.max(1, selectedRange.getRowCount() - 1)
    for row in [0...rowCount]
      @cursor.setBufferPosition([selectedRange.start.row])
      @cursor.moveToEndOfLine()
      nextRow = selectedRange.start.row + 1
      if nextRow <= @editSession.buffer.getLastRow() and @editSession.buffer.lineLengthForRow(nextRow) > 0
        @insertText(' ')
        @cursor.moveToEndOfLine()
      @modifySelection =>
        @cursor.moveRight()
        @cursor.moveToFirstCharacterOfLine()
      @deleteSelectedText()

    if joinMarker?
      newSelectedRange = joinMarker.getBufferRange()
      @setBufferRange(newSelectedRange)
      joinMarker.destroy()

  # Public: Removes one level of indent from the currently selected rows.
  outdentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    buffer = @editSession.buffer
    leadingTabRegex = new RegExp("^ {1,#{@editSession.getTabLength()}}|\t")
    for row in [start..end]
      if matchLength = buffer.lineForRow(row).match(leadingTabRegex)?[0].length
        buffer.delete [[row, 0], [row, matchLength]]

  # Public: Sets the indentation level of all selected rows to values suggested
  # by the relevant grammars.
  autoIndentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    @editSession.autoIndentBufferRows(start, end)

  # Public: Wraps the selected lines in comments if they aren't currently part
  # of a comment.
  #
  # Removes the comment if they are currently wrapped in a comment.
  #
  # Returns an Array of the commented {Range}s.
  toggleLineComments: ->
    @editSession.toggleLineCommentsForBufferRows(@getBufferRowRange()...)

  # Public: Cuts the selection until the end of the line.
  #
  # * maintainPasteboard:
  #   ?
  cutToEndOfLine: (maintainPasteboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainPasteboard)

  # Public: Copies the selection to the pasteboard and then deletes it.
  #
  # * maintainPasteboard:
  #   ?
  cut: (maintainPasteboard=false) ->
    @copy(maintainPasteboard)
    @delete()

  # Public: Copies the current selection to the pasteboard.
  #
  # * maintainPasteboard:
  #   ?
  copy: (maintainPasteboard=false) ->
    return if @isEmpty()
    text = @editSession.buffer.getTextInRange(@getBufferRange())
    if maintainPasteboard
      [currentText, metadata] = pasteboard.read()
      text = currentText + '\n' + text
    else
      metadata = { indentBasis: @editSession.indentationForBufferRow(@getBufferRange().start.row) }

    pasteboard.write(text, metadata)

  # Public: Creates a fold containing the current selection.
  fold: ->
    range = @getBufferRange()
    @editSession.createFold(range.start.row, range.end.row)
    @cursor.setBufferPosition([range.end.row + 1, 0])

  # Public: ?
  modifySelection: (fn) ->
    @retainSelection = true
    @plantTail()
    fn()
    @retainSelection = false

  # Private: Sets the marker's tail to the same position as the marker's head.
  #
  # This only works if there isn't already a tail position.
  #
  # Returns a {Point} representing the new tail position.
  plantTail: ->
    @marker.plantTail()

  # Public: Identifies if a selection intersects with a given buffer range.
  #
  # * bufferRange:
  #   A {Range} to check against
  #
  # Returns a Boolean.
  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  # Public: Identifies if a selection intersects with another selection.
  #
  # * otherSelection:
  #   A {Selection} to check against
  #
  # Returns a Boolean.
  intersectsWith: (otherSelection) ->
    @getBufferRange().intersectsWith(otherSelection.getBufferRange())

  # Public: Combines the given selection into this selection and then destroys
  # the given selection.
  #
  # * otherSelection:
  #   A {Selection} to merge with
  # * options
  #    + A hash of options matching those found in {.setBufferRange}
  merge: (otherSelection, options) ->
    myGoalBufferRange = @getGoalBufferRange()
    otherGoalBufferRange = otherSelection.getGoalBufferRange()
    if myGoalBufferRange? and otherGoalBufferRange?
      options.goalBufferRange = myGoalBufferRange.union(otherGoalBufferRange)
    else
      options.goalBufferRange = myGoalBufferRange ? otherGoalBufferRange
    @setBufferRange(@getBufferRange().union(otherSelection.getBufferRange()), options)
    otherSelection.destroy()

  # Public: ?
  compare: (other) ->
    @getBufferRange().compare(other.getBufferRange())

  # Public: Returns true if it was locally created.
  isLocal: ->
    @marker.isLocal()

  # Public: Returns true if it was created remotely.
  isRemote: ->
    @marker.isRemote()

  # Private:
  screenRangeChanged: ->
    screenRange = @getScreenRange()
    @emit 'screen-range-changed', screenRange
