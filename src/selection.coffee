{Point, Range} = require 'text-buffer'
{Model} = require 'theorist'
{pick} = require 'underscore-plus'

# Extended: Represents a selection in the {Editor}.
#
# ## Events
#
# ### screen-range-changed
#
# Extended: Emit when the selection was moved.
#
# * `screenRange` {Range} indicating the new screenrange
#
# ### destroyed
#
# Extended: Emit when the selection was destroyed
#
module.exports =
class Selection extends Model
  cursor: null
  marker: null
  editor: null
  initialScreenRange: null
  wordwise: false
  needsAutoscroll: null

  constructor: ({@cursor, @marker, @editor, id}) ->
    @assignId(id)
    @cursor.selection = this
    @decoration = @editor.decorateMarker(@marker, type: 'highlight', class: 'selection')

    @marker.on 'changed', => @screenRangeChanged()
    @marker.on 'destroyed', =>
      @destroyed = true
      @editor.removeSelection(this)
      @emit 'destroyed' unless @editor.isDestroyed()

  destroy: ->
    @marker.destroy()

  finalize: ->
    @initialScreenRange = null unless @initialScreenRange?.isEqual(@getScreenRange())
    if @isEmpty()
      @wordwise = false
      @linewise = false

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
  # * `screenRange` The new {Range} to use.
  # * `options` (optional) {Object} options matching those found in {::setBufferRange}.
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@editor.bufferRangeForScreenRange(screenRange), options)

  # Public: Returns the buffer {Range} for the selection.
  getBufferRange: ->
    @marker.getBufferRange()

  # Public: Modifies the buffer {Range} for the selection.
  #
  # * `screenRange` The new {Range} to select.
  # * `options` (optional) {Object} with the keys:
  #   * `preserveFolds` if `true`, the fold settings are preserved after the selection moves.
  #   * `autoscroll` if `true`, the {Editor} scrolls to the new selection.
  setBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    @needsAutoscroll = options.autoscroll
    options.reversed ?= @isReversed()
    @editor.destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
    @modifySelection =>
      needsFlash = options.flash
      delete options.flash if options.flash?
      @cursor.needsAutoscroll = false if @needsAutoscroll?
      @marker.setBufferRange(bufferRange, options)
      @autoscroll() if @needsAutoscroll and @editor.manageScrollPosition
      @decoration.flash('flash', @editor.selectionFlashDuration) if needsFlash

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

  getTailScreenPosition: ->
    @marker.getTailScreenPosition()

  getTailBufferPosition: ->
    @marker.getTailBufferPosition()

  getHeadScreenPosition: ->
    @marker.getHeadScreenPosition()

  getHeadBufferPosition: ->
    @marker.getHeadBufferPosition()

  autoscroll: ->
    @editor.scrollToScreenRange(@getScreenRange())

  # Public: Returns the text in the selection.
  getText: ->
    @editor.buffer.getTextInRange(@getBufferRange())

  # Public: Clears the selection, moving the marker to the head.
  clear: ->
    @marker.setAttributes(goalBufferRange: null)
    @marker.clearTail() unless @retainSelection
    @finalize()

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
  # * `row` The line {Number} to select (default: the row of the cursor).
  selectLine: (row=@cursor.getBufferPosition().row) ->
    range = @editor.bufferRangeForBufferRow(row, includeNewline: true)
    @setBufferRange(@getBufferRange().union(range))
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
  # * `position` An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    position = Point.fromObject(position)

    @modifySelection =>
      if @initialScreenRange
        if position.isLessThan(@initialScreenRange.start)
          @marker.setScreenRange([position, @initialScreenRange.end], reversed: true)
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
  # * `position` An instance of {Point}, with a given `row` and `column`.
  selectToBufferPosition: (position) ->
    @modifySelection => @cursor.setBufferPosition(position)

  # Public: Selects the text one position right of the cursor.
  selectRight: ->
    @modifySelection => @cursor.moveRight()

  # Public: Selects the text one position left of the cursor.
  selectLeft: ->
    @modifySelection => @cursor.moveLeft()

  # Public: Selects all the text one position above the cursor.
  selectUp: (rowCount) ->
    @modifySelection => @cursor.moveUp(rowCount)

  # Public: Selects all the text one position below the cursor.
  selectDown: (rowCount) ->
    @modifySelection => @cursor.moveDown(rowCount)

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
    @setBufferRange(@editor.buffer.getRange(), autoscroll: false)

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
    @modifySelection => @cursor.moveToEndOfScreenLine()

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

  # Public: Selects all the text from the current cursor position to the
  # beginning of the next paragraph.
  selectToBeginningOfNextParagraph: ->
    @modifySelection => @cursor.moveToBeginningOfNextParagraph()

  # Public: Selects all the text from the current cursor position to the
  # beginning of the previous paragraph.
  selectToBeginningOfPreviousParagraph: ->
    @modifySelection => @cursor.moveToBeginningOfPreviousParagraph()

  # Public: Moves the selection down one row.
  addSelectionBelow: ->
    range = (@getGoalBufferRange() ? @getBufferRange()).copy()
    nextRow = range.end.row + 1

    for row in [nextRow..@editor.getLastBufferRow()]
      range.start.row = row
      range.end.row = row
      clippedRange = @editor.clipBufferRange(range)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      @editor.addSelectionForBufferRange(range, goalBufferRange: range)
      break

  # FIXME: I have no idea what this does.
  getGoalBufferRange: ->
    if goalBufferRange = @marker.getAttributes().goalBufferRange
      Range.fromObject(goalBufferRange)

  # Public: Moves the selection up one row.
  addSelectionAbove: ->
    range = (@getGoalBufferRange() ? @getBufferRange()).copy()
    previousRow = range.end.row - 1

    for row in [previousRow..0]
      range.start.row = row
      range.end.row = row
      clippedRange = @editor.clipBufferRange(range)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      @editor.addSelectionForBufferRange(range, goalBufferRange: range)
      break

  # Public: Replaces text at the current selection.
  #
  # * `text` A {String} representing the text to add
  # * `options` (optional) {Object} with keys:
  #   * `select` if `true`, selects the newly added text.
  #   * `autoIndent` if `true`, indents all inserted text appropriately.
  #   * `autoIndentNewline` if `true`, indent newline appropriately.
  #   * `autoDecreaseIndent` if `true`, decreases indent level appropriately
  #     (for example, when a closing bracket is inserted).
  #   * `undo` if `skip`, skips the undo stack for this operation.
  insertText: (text, options={}) ->
    oldBufferRange = @getBufferRange()
    @editor.unfoldBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    @clear()
    @cursor.needsAutoscroll = @cursor.isLastCursor()

    if options.indentBasis? and not options.autoIndent
      text = @normalizeIndents(text, options.indentBasis)

    newBufferRange = @editor.buffer.setTextInRange(oldBufferRange, text, pick(options, 'undo'))

    if options.select
      @setBufferRange(newBufferRange, reversed: wasReversed)
    else
      @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed

    if options.autoIndent
      @editor.autoIndentBufferRow(row) for row in newBufferRange.getRows()
    else if options.autoIndentNewline and text == '\n'
      currentIndentation = @editor.indentationForBufferRow(newBufferRange.start.row)
      @editor.autoIndentBufferRow(newBufferRange.end.row, preserveLeadingWhitespace: true)
      if @editor.indentationForBufferRow(newBufferRange.end.row) < currentIndentation
        @editor.setIndentationForBufferRow(newBufferRange.end.row, currentIndentation)
    else if options.autoDecreaseIndent and /\S/.test text
      @editor.autoDecreaseIndentForBufferRow(newBufferRange.start.row)

    newBufferRange

  # Public: Indents the given text to the suggested level based on the grammar.
  #
  # * `text` The {String} to indent within the selection.
  # * `indentBasis` The beginning indent level.
  normalizeIndents: (text, indentBasis) ->
    textPrecedingCursor = @cursor.getCurrentBufferLine()[0...@cursor.getBufferColumn()]
    isCursorInsideExistingLine = /\S/.test(textPrecedingCursor)

    lines = text.split('\n')
    firstLineIndentLevel = @editor.indentLevelForLine(lines[0])
    if isCursorInsideExistingLine
      minimumIndentLevel = @editor.indentationForBufferRow(@cursor.getBufferRow())
    else
      minimumIndentLevel = @cursor.getIndentLevel()

    normalizedLines = []
    for line, i in lines
      if i == 0
        indentLevel = 0
      else if line == '' # remove all indentation from empty lines
        indentLevel = 0
      else
        lineIndentLevel = @editor.indentLevelForLine(lines[i])
        indentLevel = minimumIndentLevel + (lineIndentLevel - indentBasis)

      normalizedLines.push(@setIndentationForLine(line, indentLevel))

    normalizedLines.join('\n')

  # Indent the current line(s).
  #
  # If the selection is empty, indents the current line if the cursor precedes
  # non-whitespace characters, and otherwise inserts a tab. If the selection is
  # non empty, calls {::indentSelectedRows}.
  #
  # * `options` (optional) {Object} with the keys:
  #   * `autoIndent` If `true`, the line is indented to an automatically-inferred
  #     level. Otherwise, {Editor::getTabText} is inserted.
  indent: ({ autoIndent }={}) ->
    { row, column } = @cursor.getBufferPosition()

    if @isEmpty()
      @cursor.skipLeadingWhitespace()
      desiredIndent = @editor.suggestedIndentForBufferRow(row)
      delta = desiredIndent - @cursor.getIndentLevel()

      if autoIndent and delta > 0
        @insertText(@editor.buildIndentString(delta))
      else
        @insertText(@editor.buildIndentString(1, @cursor.getBufferColumn()))
    else
      @indentSelectedRows()

  # Public: If the selection spans multiple rows, indent all of them.
  indentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    for row in [start..end]
      @editor.buffer.insert([row, 0], @editor.getTabText()) unless @editor.buffer.lineLengthForRow(row) == 0

  # Public: ?
  setIndentationForLine: (line, indentLevel) ->
    desiredIndentLevel = Math.max(0, indentLevel)
    desiredIndentString = @editor.buildIndentString(desiredIndentLevel)
    line.replace(/^[\t ]*/, desiredIndentString)

  # Public: Removes the first character before the selection if the selection
  # is empty otherwise it deletes the selection.
  backspace: ->
    @selectLeft() if @isEmpty() and not @editor.isFoldedAtScreenRow(@cursor.getScreenRow())
    @deleteSelectedText()

  # Deprecated: Use {::deleteToBeginningOfWord} instead.
  backspaceToBeginningOfWord: ->
    deprecate("Use Selection::deleteToBeginningOfWord() instead")
    @deleteToBeginningOfWord()

  # Deprecated: Use {::deleteToBeginningOfLine} instead.
  backspaceToBeginningOfLine: ->
    deprecate("Use Selection::deleteToBeginningOfLine() instead")
    @deleteToBeginningOfLine()

  # Public: Removes from the start of the selection to the beginning of the
  # current word if the selection is empty otherwise it deletes the selection.
  deleteToBeginningOfWord: ->
    @selectToBeginningOfWord() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes from the beginning of the line which the selection begins on
  # all the way through to the end of the selection.
  deleteToBeginningOfLine: ->
    if @isEmpty() and @cursor.isAtBeginningOfLine()
      @selectLeft()
    else
      @selectToBeginningOfLine()
    @deleteSelectedText()

  # Public: Removes the selection or the next character after the start of the
  # selection if the selection is empty.
  delete: ->
    if @isEmpty()
      if @cursor.isAtEndOfLine() and fold = @editor.largestFoldStartingAtScreenRow(@cursor.getScreenRow() + 1)
        @selectToBufferPosition(fold.getBufferRange().end)
      else
        @selectRight()
    @deleteSelectedText()

  # Public: If the selection is empty, removes all text from the cursor to the
  # end of the line. If the cursor is already at the end of the line, it
  # removes the following newline. If the selection isn't empty, only deletes
  # the contents of the selection.
  deleteToEndOfLine: ->
    return @delete() if @isEmpty() and @cursor.isAtEndOfLine()
    @selectToEndOfLine() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes the selection or all characters from the start of the
  # selection to the end of the current word if nothing is selected.
  deleteToEndOfWord: ->
    @selectToEndOfWord() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes only the selected text.
  deleteSelectedText: ->
    bufferRange = @getBufferRange()
    if bufferRange.isEmpty() and fold = @editor.largestFoldContainingBufferRow(bufferRange.start.row)
      bufferRange = bufferRange.union(fold.getBufferRange(includeNewline: true))
    @editor.buffer.delete(bufferRange) unless bufferRange.isEmpty()
    @cursor?.setBufferPosition(bufferRange.start)

  # Public: Removes the line at the beginning of the selection if the selection
  # is empty unless the selection spans multiple lines in which case all lines
  # are removed.
  deleteLine: ->
    if @isEmpty()
      start = @cursor.getScreenRow()
      range = @editor.bufferRowsForScreenRows(start, start + 1)
      if range[1] > range[0]
        @editor.buffer.deleteRows(range[0], range[1] - 1)
      else
        @editor.buffer.deleteRow(range[0])
    else
      range = @getBufferRange()
      start = range.start.row
      end = range.end.row
      if end isnt @editor.buffer.getLastRow() and range.end.column is 0
        end--
      @editor.buffer.deleteRows(start, end)

  # Public: Joins the current line with the one below it.
  #
  # If there selection spans more than one line, all the lines are joined together.
  joinLines: ->
    selectedRange = @getBufferRange()
    if selectedRange.isEmpty()
      return if selectedRange.start.row is @editor.buffer.getLastRow()
    else
      joinMarker = @editor.markBufferRange(selectedRange, invalidationStrategy: 'never')

    rowCount = Math.max(1, selectedRange.getRowCount() - 1)
    for row in [0...rowCount]
      @cursor.setBufferPosition([selectedRange.start.row])
      @cursor.moveToEndOfLine()
      nextRow = selectedRange.start.row + 1
      if nextRow <= @editor.buffer.getLastRow() and @editor.buffer.lineLengthForRow(nextRow) > 0
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
    buffer = @editor.buffer
    leadingTabRegex = new RegExp("^( {1,#{@editor.getTabLength()}}|\t)")
    for row in [start..end]
      if matchLength = buffer.lineForRow(row).match(leadingTabRegex)?[0].length
        buffer.delete [[row, 0], [row, matchLength]]

  # Public: Sets the indentation level of all selected rows to values suggested
  # by the relevant grammars.
  autoIndentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    @editor.autoIndentBufferRows(start, end)

  # Public: Wraps the selected lines in comments if they aren't currently part
  # of a comment.
  #
  # Removes the comment if they are currently wrapped in a comment.
  #
  # Returns an Array of the commented {Range}s.
  toggleLineComments: ->
    @editor.toggleLineCommentsForBufferRows(@getBufferRowRange()...)

  # Public: Cuts the selection until the end of the line.
  cutToEndOfLine: (maintainClipboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainClipboard)

  # Public: Copies the selection to the clipboard and then deletes it.
  #
  # * `maintainClipboard` {Boolean} (default: false) See {::copy}
  cut: (maintainClipboard=false) ->
    @copy(maintainClipboard)
    @delete()

  # Public: Copies the current selection to the clipboard.
  #
  # * `maintainClipboard` {Boolean} if `true`, a specific metadata property
  #   is created to store each content copied to the clipboard. The clipboard
  #   `text` still contains the concatenation of the clipboard with the
  #   current selection. (default: false)
  copy: (maintainClipboard=false) ->
    return if @isEmpty()
    text = @editor.buffer.getTextInRange(@getBufferRange())
    if maintainClipboard
      {text: clipboardText, metadata} = atom.clipboard.readWithMetadata()

      if metadata?.selections?
        metadata.selections.push(text)
      else
        metadata = { selections: [clipboardText, text] }

      text = "" + (clipboardText) + "\n" + text
    else
      metadata = { indentBasis: @editor.indentationForBufferRow(@getBufferRange().start.row) }

    atom.clipboard.write(text, metadata)

  # Public: Creates a fold containing the current selection.
  fold: ->
    range = @getBufferRange()
    @editor.createFold(range.start.row, range.end.row)
    @cursor.setBufferPosition([range.end.row + 1, 0])

  modifySelection: (fn) ->
    @retainSelection = true
    @plantTail()
    fn()
    @retainSelection = false

  # Sets the marker's tail to the same position as the marker's head.
  #
  # This only works if there isn't already a tail position.
  #
  # Returns a {Point} representing the new tail position.
  plantTail: ->
    @marker.plantTail()

  # Public: Identifies if a selection intersects with a given buffer range.
  #
  # * `bufferRange` A {Range} to check against.
  #
  # Returns a {Boolean}
  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  intersectsScreenRowRange: (startRow, endRow) ->
    @getScreenRange().intersectsRowRange(startRow, endRow)

  intersectsScreenRow: (screenRow) ->
    @getScreenRange().intersectsRow(screenRow)

  # Public: Identifies if a selection intersects with another selection.
  #
  # * `otherSelection` A {Selection} to check against.
  #
  # Returns a {Boolean}
  intersectsWith: (otherSelection, exclusive) ->
    @getBufferRange().intersectsWith(otherSelection.getBufferRange(), exclusive)

  # Public: Combines the given selection into this selection and then destroys
  # the given selection.
  #
  # * `otherSelection` A {Selection} to merge with.
  # * `options` (optional) {Object} options matching those found in {::setBufferRange}.
  merge: (otherSelection, options) ->
    myGoalBufferRange = @getGoalBufferRange()
    otherGoalBufferRange = otherSelection.getGoalBufferRange()
    if myGoalBufferRange? and otherGoalBufferRange?
      options.goalBufferRange = myGoalBufferRange.union(otherGoalBufferRange)
    else
      options.goalBufferRange = myGoalBufferRange ? otherGoalBufferRange
    @setBufferRange(@getBufferRange().union(otherSelection.getBufferRange()), options)
    otherSelection.destroy()

  # Public: Compare this selection's buffer range to another selection's buffer
  # range.
  #
  # See {Range::compare} for more details.
  #
  # * `otherSelection` A {Selection} to compare against
  compare: (otherSelection) ->
    @getBufferRange().compare(otherSelection.getBufferRange())

  screenRangeChanged: ->
    screenRange = @getScreenRange()
    @emit 'screen-range-changed', screenRange
    @editor.selectionScreenRangeChanged(this)
