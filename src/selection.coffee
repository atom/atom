{Point, Range} = require 'text-buffer'
{pick} = require 'underscore-plus'
{Emitter} = require 'event-kit'
Model = require './model'

NonWhitespaceRegExp = /\S/

# Extended: Represents a selection in the {TextEditor}.
module.exports =
class Selection extends Model
  cursor: null
  marker: null
  editor: null
  initialScreenRange: null
  wordwise: false

  constructor: ({@cursor, @marker, @editor, id}) ->
    @emitter = new Emitter

    @assignId(id)
    @cursor.selection = this
    @decoration = @editor.decorateMarker(@marker, type: 'highlight', class: 'selection')

    @marker.onDidChange (e) => @markerDidChange(e)
    @marker.onDidDestroy => @markerDidDestroy()

  destroy: ->
    @marker.destroy()

  isLastSelection: ->
    this is @editor.getLastSelection()

  ###
  Section: Event Subscription
  ###

  # Extended: Calls your `callback` when the selection was moved.
  #
  # * `callback` {Function}
  #   * `event` {Object}
  #     * `oldBufferRange` {Range}
  #     * `oldScreenRange` {Range}
  #     * `newBufferRange` {Range}
  #     * `newScreenRange` {Range}
  #     * `selection` {Selection} that triggered the event
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidChangeRange: (callback) ->
    @emitter.on 'did-change-range', callback

  # Extended: Calls your `callback` when the selection was destroyed
  #
  # * `callback` {Function}
  #
  # Returns a {Disposable} on which `.dispose()` can be called to unsubscribe.
  onDidDestroy: (callback) ->
    @emitter.on 'did-destroy', callback

  ###
  Section: Managing the selection range
  ###

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
  # * `bufferRange` The new {Range} to select.
  # * `options` (optional) {Object} with the keys:
  #   * `preserveFolds` if `true`, the fold settings are preserved after the
  #     selection moves.
  #   * `autoscroll` {Boolean} indicating whether to autoscroll to the new
  #     range. Defaults to `true` if this is the most recently added selection,
  #     `false` otherwise.
  setBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    options.reversed ?= @isReversed()
    @editor.destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
    @modifySelection =>
      needsFlash = options.flash
      delete options.flash if options.flash?
      @marker.setBufferRange(bufferRange, options)
      @autoscroll() if options?.autoscroll ? @isLastSelection()
      @decoration.flash('flash', @editor.selectionFlashDuration) if needsFlash

  # Public: Returns the starting and ending buffer rows the selection is
  # highlighting.
  #
  # Returns an {Array} of two {Number}s: the starting row, and the ending row.
  getBufferRowRange: ->
    range = @getBufferRange()
    start = range.start.row
    end = range.end.row
    end = Math.max(start, end - 1) if range.end.column is 0
    [start, end]

  getTailScreenPosition: ->
    @marker.getTailScreenPosition()

  getTailBufferPosition: ->
    @marker.getTailBufferPosition()

  getHeadScreenPosition: ->
    @marker.getHeadScreenPosition()

  getHeadBufferPosition: ->
    @marker.getHeadBufferPosition()

  ###
  Section: Info about the selection
  ###

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

  # Public: Returns the text in the selection.
  getText: ->
    @editor.buffer.getTextInRange(@getBufferRange())

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

  ###
  Section: Modifying the selected range
  ###

  # Public: Clears the selection, moving the marker to the head.
  #
  # * `options` (optional) {Object} with the following keys:
  #   * `autoscroll` {Boolean} indicating whether to autoscroll to the new
  #     range. Defaults to `true` if this is the most recently added selection,
  #     `false` otherwise.
  clear: (options) ->
    @goalScreenRange = null
    @marker.clearTail() unless @retainSelection
    @autoscroll() if options?.autoscroll ? @isLastSelection()
    @finalize()

  # Public: Selects the text from the current cursor position to a given screen
  # position.
  #
  # * `position` An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position, options) ->
    position = Point.fromObject(position)

    @modifySelection =>
      if @initialScreenRange
        if position.isLessThan(@initialScreenRange.start)
          @marker.setScreenRange([position, @initialScreenRange.end], reversed: true)
        else
          @marker.setScreenRange([@initialScreenRange.start, position], reversed: false)
      else
        @cursor.setScreenPosition(position, options)

      if @linewise
        @expandOverLine(options)
      else if @wordwise
        @expandOverWord(options)

  # Public: Selects the text from the current cursor position to a given buffer
  # position.
  #
  # * `position` An instance of {Point}, with a given `row` and `column`.
  selectToBufferPosition: (position) ->
    @modifySelection => @cursor.setBufferPosition(position)

  # Public: Selects the text one position right of the cursor.
  #
  # * `columnCount` (optional) {Number} number of columns to select (default: 1)
  selectRight: (columnCount) ->
    @modifySelection => @cursor.moveRight(columnCount)

  # Public: Selects the text one position left of the cursor.
  #
  # * `columnCount` (optional) {Number} number of columns to select (default: 1)
  selectLeft: (columnCount) ->
    @modifySelection => @cursor.moveLeft(columnCount)

  # Public: Selects all the text one position above the cursor.
  #
  # * `rowCount` (optional) {Number} number of rows to select (default: 1)
  selectUp: (rowCount) ->
    @modifySelection => @cursor.moveUp(rowCount)

  # Public: Selects all the text one position below the cursor.
  #
  # * `rowCount` (optional) {Number} number of rows to select (default: 1)
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
  # the screen line.
  selectToEndOfLine: ->
    @modifySelection => @cursor.moveToEndOfScreenLine()

  # Public: Selects all the text from the current cursor position to the end of
  # the buffer line.
  selectToEndOfBufferLine: ->
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

  # Public: Selects text to the previous subword boundary.
  selectToPreviousSubwordBoundary: ->
    @modifySelection => @cursor.moveToPreviousSubwordBoundary()

  # Public: Selects text to the next subword boundary.
  selectToNextSubwordBoundary: ->
    @modifySelection => @cursor.moveToNextSubwordBoundary()

  # Public: Selects all the text from the current cursor position to the
  # beginning of the next paragraph.
  selectToBeginningOfNextParagraph: ->
    @modifySelection => @cursor.moveToBeginningOfNextParagraph()

  # Public: Selects all the text from the current cursor position to the
  # beginning of the previous paragraph.
  selectToBeginningOfPreviousParagraph: ->
    @modifySelection => @cursor.moveToBeginningOfPreviousParagraph()

  # Public: Modifies the selection to encompass the current word.
  #
  # Returns a {Range}.
  selectWord: (options={}) ->
    options.wordRegex = /[\t ]*/ if @cursor.isSurroundedByWhitespace()
    if @cursor.isBetweenWordAndNonWord()
      options.includeNonWordCharacters = false

    @setBufferRange(@cursor.getCurrentWordBufferRange(options), options)
    @wordwise = true
    @initialScreenRange = @getScreenRange()

  # Public: Expands the newest selection to include the entire word on which
  # the cursors rests.
  expandOverWord: (options) ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentWordBufferRange()), autoscroll: false)
    @cursor.autoscroll() if options?.autoscroll ? true

  # Public: Selects an entire line in the buffer.
  #
  # * `row` The line {Number} to select (default: the row of the cursor).
  selectLine: (row, options) ->
    if row?
      @setBufferRange(@editor.bufferRangeForBufferRow(row, includeNewline: true), options)
    else
      startRange = @editor.bufferRangeForBufferRow(@marker.getStartBufferPosition().row)
      endRange = @editor.bufferRangeForBufferRow(@marker.getEndBufferPosition().row, includeNewline: true)
      @setBufferRange(startRange.union(endRange), options)

    @linewise = true
    @wordwise = false
    @initialScreenRange = @getScreenRange()

  # Public: Expands the newest selection to include the entire line on which
  # the cursor currently rests.
  #
  # It also includes the newline character.
  expandOverLine: (options) ->
    range = @getBufferRange().union(@cursor.getCurrentLineBufferRange(includeNewline: true))
    @setBufferRange(range, autoscroll: false)
    @cursor.autoscroll() if options?.autoscroll ? true

  ###
  Section: Modifying the selected text
  ###

  # Public: Replaces text at the current selection.
  #
  # * `text` A {String} representing the text to add
  # * `options` (optional) {Object} with keys:
  #   * `select` if `true`, selects the newly added text.
  #   * `autoIndent` if `true`, indents all inserted text appropriately.
  #   * `autoIndentNewline` if `true`, indent newline appropriately.
  #   * `autoDecreaseIndent` if `true`, decreases indent level appropriately
  #     (for example, when a closing bracket is inserted).
  #   * `normalizeLineEndings` (optional) {Boolean} (default: true)
  #   * `undo` if `skip`, skips the undo stack for this operation.
  insertText: (text, options={}) ->
    oldBufferRange = @getBufferRange()
    wasReversed = @isReversed()
    @clear(options)

    autoIndentFirstLine = false
    precedingText = @editor.getTextInRange([[oldBufferRange.start.row, 0], oldBufferRange.start])
    remainingLines = text.split('\n')
    firstInsertedLine = remainingLines.shift()

    if options.indentBasis?
      indentAdjustment = @editor.indentLevelForLine(precedingText) - options.indentBasis
      @adjustIndent(remainingLines, indentAdjustment)

    textIsAutoIndentable = text is '\n' or text is '\r\n' or NonWhitespaceRegExp.test(text)
    if options.autoIndent and textIsAutoIndentable and not NonWhitespaceRegExp.test(precedingText) and remainingLines.length > 0
      autoIndentFirstLine = true
      firstLine = precedingText + firstInsertedLine
      desiredIndentLevel = @editor.languageMode.suggestedIndentForLineAtBufferRow(oldBufferRange.start.row, firstLine)
      indentAdjustment = desiredIndentLevel - @editor.indentLevelForLine(firstLine)
      @adjustIndent(remainingLines, indentAdjustment)

    text = firstInsertedLine
    text += '\n' + remainingLines.join('\n') if remainingLines.length > 0

    newBufferRange = @editor.buffer.setTextInRange(oldBufferRange, text, pick(options, 'undo', 'normalizeLineEndings'))

    if options.select
      @setBufferRange(newBufferRange, reversed: wasReversed)
    else
      @cursor.setBufferPosition(newBufferRange.end) if wasReversed

    if autoIndentFirstLine
      @editor.setIndentationForBufferRow(oldBufferRange.start.row, desiredIndentLevel)

    if options.autoIndentNewline and text is '\n'
      @editor.autoIndentBufferRow(newBufferRange.end.row, preserveLeadingWhitespace: true, skipBlankLines: false)
    else if options.autoDecreaseIndent and NonWhitespaceRegExp.test(text)
      @editor.autoDecreaseIndentForBufferRow(newBufferRange.start.row)

    @autoscroll() if options.autoscroll ? @isLastSelection()

    newBufferRange

  # Public: Removes the first character before the selection if the selection
  # is empty otherwise it deletes the selection.
  backspace: ->
    @selectLeft() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes the selection or, if nothing is selected, then all
  # characters from the start of the selection back to the previous word
  # boundary.
  deleteToPreviousWordBoundary: ->
    @selectToPreviousWordBoundary() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes the selection or, if nothing is selected, then all
  # characters from the start of the selection up to the next word
  # boundary.
  deleteToNextWordBoundary: ->
    @selectToNextWordBoundary() if @isEmpty()
    @deleteSelectedText()

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
    @selectRight() if @isEmpty()
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

  # Public: Removes the selection or all characters from the start of the
  # selection to the end of the current word if nothing is selected.
  deleteToBeginningOfSubword: ->
    @selectToPreviousSubwordBoundary() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes the selection or all characters from the start of the
  # selection to the end of the current word if nothing is selected.
  deleteToEndOfSubword: ->
    @selectToNextSubwordBoundary() if @isEmpty()
    @deleteSelectedText()

  # Public: Removes only the selected text.
  deleteSelectedText: ->
    bufferRange = @getBufferRange()
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

  # Public: Joins the current line with the one below it. Lines will
  # be separated by a single space.
  #
  # If there selection spans more than one line, all the lines are joined together.
  joinLines: ->
    selectedRange = @getBufferRange()
    if selectedRange.isEmpty()
      return if selectedRange.start.row is @editor.buffer.getLastRow()
    else
      joinMarker = @editor.markBufferRange(selectedRange, invalidate: 'never')

    rowCount = Math.max(1, selectedRange.getRowCount() - 1)
    for [0...rowCount]
      @cursor.setBufferPosition([selectedRange.start.row])
      @cursor.moveToEndOfLine()

      # Remove trailing whitespace from the current line
      scanRange = @cursor.getCurrentLineBufferRange()
      trailingWhitespaceRange = null
      @editor.scanInBufferRange /[ \t]+$/, scanRange, ({range}) ->
        trailingWhitespaceRange = range
      if trailingWhitespaceRange?
        @setBufferRange(trailingWhitespaceRange)
        @deleteSelectedText()

      currentRow = selectedRange.start.row
      nextRow = currentRow + 1
      insertSpace = nextRow <= @editor.buffer.getLastRow() and
                    @editor.buffer.lineLengthForRow(nextRow) > 0 and
                    @editor.buffer.lineLengthForRow(currentRow) > 0
      @insertText(' ') if insertSpace

      @cursor.moveToEndOfLine()

      # Remove leading whitespace from the line below
      @modifySelection =>
        @cursor.moveRight()
        @cursor.moveToFirstCharacterOfLine()
      @deleteSelectedText()

      @cursor.moveLeft() if insertSpace

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
    return

  # Public: Sets the indentation level of all selected rows to values suggested
  # by the relevant grammars.
  autoIndentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    @editor.autoIndentBufferRows(start, end)

  # Public: Wraps the selected lines in comments if they aren't currently part
  # of a comment.
  #
  # Removes the comment if they are currently wrapped in a comment.
  toggleLineComments: ->
    @editor.toggleLineCommentsForBufferRows(@getBufferRowRange()...)

  # Public: Cuts the selection until the end of the screen line.
  cutToEndOfLine: (maintainClipboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainClipboard)

  # Public: Cuts the selection until the end of the buffer line.
  cutToEndOfBufferLine: (maintainClipboard) ->
    @selectToEndOfBufferLine() if @isEmpty()
    @cut(maintainClipboard)

  # Public: Copies the selection to the clipboard and then deletes it.
  #
  # * `maintainClipboard` {Boolean} (default: false) See {::copy}
  # * `fullLine` {Boolean} (default: false) See {::copy}
  cut: (maintainClipboard=false, fullLine=false) ->
    @copy(maintainClipboard, fullLine)
    @delete()

  # Public: Copies the current selection to the clipboard.
  #
  # * `maintainClipboard` {Boolean} if `true`, a specific metadata property
  #   is created to store each content copied to the clipboard. The clipboard
  #   `text` still contains the concatenation of the clipboard with the
  #   current selection. (default: false)
  # * `fullLine` {Boolean} if `true`, the copied text will always be pasted
  #   at the beginning of the line containing the cursor, regardless of the
  #   cursor's horizontal position. (default: false)
  copy: (maintainClipboard=false, fullLine=false) ->
    return if @isEmpty()
    {start, end} = @getBufferRange()
    selectionText = @editor.getTextInRange([start, end])
    precedingText = @editor.getTextInRange([[start.row, 0], start])
    startLevel = @editor.indentLevelForLine(precedingText)

    if maintainClipboard
      {text: clipboardText, metadata} = @editor.constructor.clipboard.readWithMetadata()
      metadata ?= {}
      unless metadata.selections?
        metadata.selections = [{
          text: clipboardText,
          indentBasis: metadata.indentBasis,
          fullLine: metadata.fullLine,
        }]
      metadata.selections.push({
        text: selectionText,
        indentBasis: startLevel,
        fullLine: fullLine
      })
      @editor.constructor.clipboard.write([clipboardText, selectionText].join("\n"), metadata)
    else
      @editor.constructor.clipboard.write(selectionText, {
        indentBasis: startLevel,
        fullLine: fullLine
      })

  # Public: Creates a fold containing the current selection.
  fold: ->
    range = @getBufferRange()
    unless range.isEmpty()
      @editor.foldBufferRange(range)
      @cursor.setBufferPosition(range.end)

  # Private: Increase the indentation level of the given text by given number
  # of levels. Leaves the first line unchanged.
  adjustIndent: (lines, indentAdjustment) ->
    for line, i in lines
      if indentAdjustment is 0 or line is ''
        continue
      else if indentAdjustment > 0
        lines[i] = @editor.buildIndentString(indentAdjustment) + line
      else
        currentIndentLevel = @editor.indentLevelForLine(lines[i])
        indentLevel = Math.max(0, currentIndentLevel + indentAdjustment)
        lines[i] = line.replace(/^[\t ]+/, @editor.buildIndentString(indentLevel))
    return

  # Indent the current line(s).
  #
  # If the selection is empty, indents the current line if the cursor precedes
  # non-whitespace characters, and otherwise inserts a tab. If the selection is
  # non empty, calls {::indentSelectedRows}.
  #
  # * `options` (optional) {Object} with the keys:
  #   * `autoIndent` If `true`, the line is indented to an automatically-inferred
  #     level. Otherwise, {TextEditor::getTabText} is inserted.
  indent: ({autoIndent}={}) ->
    {row} = @cursor.getBufferPosition()

    if @isEmpty()
      @cursor.skipLeadingWhitespace()
      desiredIndent = @editor.suggestedIndentForBufferRow(row)
      delta = desiredIndent - @cursor.getIndentLevel()

      if autoIndent and delta > 0
        delta = Math.max(delta, 1) unless @editor.getSoftTabs()
        @insertText(@editor.buildIndentString(delta))
      else
        @insertText(@editor.buildIndentString(1, @cursor.getBufferColumn()))
    else
      @indentSelectedRows()

  # Public: If the selection spans multiple rows, indent all of them.
  indentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    for row in [start..end]
      @editor.buffer.insert([row, 0], @editor.getTabText()) unless @editor.buffer.lineLengthForRow(row) is 0
    return

  ###
  Section: Managing multiple selections
  ###

  # Public: Moves the selection down one row.
  addSelectionBelow: ->
    range = @getGoalScreenRange().copy()
    nextRow = range.end.row + 1

    for row in [nextRow..@editor.getLastScreenRow()]
      range.start.row = row
      range.end.row = row
      clippedRange = @editor.clipScreenRange(range, skipSoftWrapIndentation: true)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      selection = @editor.addSelectionForScreenRange(clippedRange)
      selection.setGoalScreenRange(range)
      break

    return

  # Public: Moves the selection up one row.
  addSelectionAbove: ->
    range = @getGoalScreenRange().copy()
    previousRow = range.end.row - 1

    for row in [previousRow..0]
      range.start.row = row
      range.end.row = row
      clippedRange = @editor.clipScreenRange(range, skipSoftWrapIndentation: true)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      selection = @editor.addSelectionForScreenRange(clippedRange)
      selection.setGoalScreenRange(range)
      break

    return

  # Public: Combines the given selection into this selection and then destroys
  # the given selection.
  #
  # * `otherSelection` A {Selection} to merge with.
  # * `options` (optional) {Object} options matching those found in {::setBufferRange}.
  merge: (otherSelection, options) ->
    myGoalScreenRange = @getGoalScreenRange()
    otherGoalScreenRange = otherSelection.getGoalScreenRange()

    if myGoalScreenRange? and otherGoalScreenRange?
      options.goalScreenRange = myGoalScreenRange.union(otherGoalScreenRange)
    else
      options.goalScreenRange = myGoalScreenRange ? otherGoalScreenRange

    @setBufferRange(@getBufferRange().union(otherSelection.getBufferRange()), Object.assign(autoscroll: false, options))
    otherSelection.destroy()

  ###
  Section: Comparing to other selections
  ###

  # Public: Compare this selection's buffer range to another selection's buffer
  # range.
  #
  # See {Range::compare} for more details.
  #
  # * `otherSelection` A {Selection} to compare against
  compare: (otherSelection) ->
    @marker.compare(otherSelection.marker)

  ###
  Section: Private Utilities
  ###

  setGoalScreenRange: (range) ->
    @goalScreenRange = Range.fromObject(range)

  getGoalScreenRange: ->
    @goalScreenRange ? @getScreenRange()

  markerDidChange: (e) ->
    {oldHeadBufferPosition, oldTailBufferPosition, newHeadBufferPosition} = e
    {oldHeadScreenPosition, oldTailScreenPosition, newHeadScreenPosition} = e
    {textChanged} = e

    @cursor.updateVisibility()

    unless oldHeadScreenPosition.isEqual(newHeadScreenPosition)
      @cursor.goalColumn = null
      cursorMovedEvent = {
        oldBufferPosition: oldHeadBufferPosition
        oldScreenPosition: oldHeadScreenPosition
        newBufferPosition: newHeadBufferPosition
        newScreenPosition: newHeadScreenPosition
        textChanged: textChanged
        cursor: @cursor
      }
      @cursor.emitter.emit('did-change-position', cursorMovedEvent)
      @editor.cursorMoved(cursorMovedEvent)

    @emitter.emit 'did-change-range'
    @editor.selectionRangeChanged(
      oldBufferRange: new Range(oldHeadBufferPosition, oldTailBufferPosition)
      oldScreenRange: new Range(oldHeadScreenPosition, oldTailScreenPosition)
      newBufferRange: @getBufferRange()
      newScreenRange: @getScreenRange()
      selection: this
    )

  markerDidDestroy: ->
    return if @editor.isDestroyed()

    @destroyed = true
    @cursor.destroyed = true

    @editor.removeSelection(this)

    @cursor.emitter.emit 'did-destroy'
    @emitter.emit 'did-destroy'

    @cursor.emitter.dispose()
    @emitter.dispose()

  finalize: ->
    @initialScreenRange = null unless @initialScreenRange?.isEqual(@getScreenRange())
    if @isEmpty()
      @wordwise = false
      @linewise = false

  autoscroll: (options) ->
    if @marker.hasTail()
      @editor.scrollToScreenRange(@getScreenRange(), Object.assign({reversed: @isReversed()}, options))
    else
      @cursor.autoscroll(options)

  clearAutoscroll: ->

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
