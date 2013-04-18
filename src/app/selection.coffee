Range = require 'range'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

# Public: Represents a selection in the {EditSession}.
module.exports =
class Selection
  cursor: null
  marker: null
  editSession: null
  initialScreenRange: null
  goalBufferRange: null
  wordwise: false
  needsAutoscroll: null

  # Internal:
  constructor: ({@cursor, @marker, @editSession, @goalBufferRange}) ->
    @cursor.selection = this
    @editSession.observeMarker @marker, => @screenRangeChanged()
    @cursor.on 'destroyed.selection', =>
      @cursor = null
      @destroy()

  # Internal:
  destroy: ->
    return if @destroyed
    @destroyed = true
    @editSession.removeSelection(this)
    @trigger 'destroyed' unless @editSession.destroyed
    @cursor?.destroy()

  # Internal:
  finalize: ->
    @initialScreenRange = null unless @initialScreenRange?.isEqual(@getScreenRange())
    if @isEmpty()
      @wordwise = false
      @linewise = false

  # Public: Identifies if the selection is highlighting anything.
  #
  # Returns a {Boolean}.
  isEmpty: ->
    @getBufferRange().isEmpty()

  # Public: Identifies if the selection is reversed, that is, it is highlighting "up."
  #
  # Returns a {Boolean}.
  isReversed: ->
    @editSession.isMarkerReversed(@marker)

  # Public: Identifies if the selection is a single line.
  #
  # Returns a {Boolean}.
  isSingleScreenLine: ->
    @getScreenRange().isSingleLine()

  # Internal:
  clearAutoscroll: ->
    @needsAutoscroll = null

  # Public: Retrieves the screen range for the selection.
  #
  # Returns a {Range}.
  getScreenRange: ->
    @editSession.getMarkerScreenRange(@marker)

  # Public: Modifies the screen range for the selection.
  #
  # screenRange - The new {Range} to select
  # options - A hash of options matching those found in {.setBufferRange}
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@editSession.bufferRangeForScreenRange(screenRange), options)

  # Public: Retrieves the buffer range for the selection.
  #
  # Returns a {Range}.
  getBufferRange: ->
    @editSession.getMarkerBufferRange(@marker)

  # Public: Modifies the buffer range for the selection.
  #
  # screenRange - The new {Range} to select
  # options - A hash of options with the following keys:
  #           :preserveFolds - if `true`, the fold settings are preserved after the selection moves
  #           :autoscroll - if `true`, the {EditSession} scrolls to the new selection
  setBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    @needsAutoscroll = options.autoscroll
    options.reverse ?= @isReversed()
    @editSession.destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
    @modifySelection =>
      @cursor.needsAutoscroll = false if options.autoscroll?
      @editSession.setMarkerBufferRange(@marker, bufferRange, options)

  # Public: Retrieves the starting and ending buffer rows the selection is highlighting.
  #
  # Returns an {Array} of two {Number}s: the starting row, and the ending row.
  getBufferRowRange: ->
    range = @getBufferRange()
    start = range.start.row
    end = range.end.row
    end = Math.max(start, end - 1) if range.end.column == 0
    [start, end]

  # Internal:
  screenRangeChanged: ->
    screenRange = @getScreenRange()
    @trigger 'screen-range-changed', screenRange

  # Public: Retrieves the text in the selection.
  #
  # Returns a {String}.
  getText: ->
    @editSession.buffer.getTextInRange(@getBufferRange())

  # Public: Clears the selection, moving the marker to move to the head.
  clear: ->
    @editSession.clearMarkerTail(@marker)

  # Public: Modifies the selection to mark the current word.
  #
  # Returns a {Range}.
  selectWord: ->
    options = {}
    options.wordRegex = /[\t ]*/ if @cursor.isSurroundedByWhitespace()

    @setBufferRange(@cursor.getCurrentWordBufferRange(options))
    @wordwise = true
    @initialScreenRange = @getScreenRange()

  expandOverWord: ->
    @setBufferRange(@getBufferRange().union(@cursor.getCurrentWordBufferRange()))

  # Public: Selects an entire line in the {Buffer}.
  #
  # row - The line {Number} to select (default: the row of the cursor)
  selectLine: (row=@cursor.getBufferPosition().row) ->
    range = @editSession.bufferRangeForBufferRow(row, includeNewline: true)
    @setBufferRange(range)
    @linewise = true
    @wordwise = false
    @initialScreenRange = @getScreenRange()

  expandOverLine: ->
    range = @getBufferRange().union(@cursor.getCurrentLineBufferRange(includeNewline: true))
    @setBufferRange(range)

  # Public: Selects the text from the current cursor position to a given screen position.
  #
  # position - An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    @modifySelection =>
      if @initialScreenRange
        if position.isLessThan(@initialScreenRange.start)
          @editSession.setMarkerScreenRange(@marker, [position, @initialScreenRange.end], reverse: true)
        else
          @editSession.setMarkerScreenRange(@marker, [@initialScreenRange.start, position])
      else
        @cursor.setScreenPosition(position)

      if @linewise
        @expandOverLine()
      else if @wordwise
        @expandOverWord()

  # Public: Selects the text from the current cursor position to a given buffer position.
  #
  # position - An instance of {Point}, with a given `row` and `column`.
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

  # Public: Selects all the text from the current cursor position to the top of the buffer.
  selectToTop: ->
    @modifySelection => @cursor.moveToTop()

  # Public: Selects all the text from the current cursor position to the bottom of the buffer.
  selectToBottom: ->
    @modifySelection => @cursor.moveToBottom()

  # Public: Selects all the text in the buffer.
  selectAll: ->
    @setBufferRange(@editSession.buffer.getRange(), autoscroll: false)

  # Public: Selects all the text from the current cursor position to the beginning of the line.
  selectToBeginningOfLine: ->
    @modifySelection => @cursor.moveToBeginningOfLine()

  # Public: Selects all the text from the current cursor position to the end of the line.
  selectToEndOfLine: ->
    @modifySelection => @cursor.moveToEndOfLine()

  # Public: Selects all the text from the current cursor position to the beginning of the word.
  selectToBeginningOfWord: ->
    @modifySelection => @cursor.moveToBeginningOfWord()

  # Public: Selects all the text from the current cursor position to the end of the word.
  selectToEndOfWord: ->
    @modifySelection => @cursor.moveToEndOfWord()

  # Public: Selects all the text from the current cursor position to the beginning of the next word.
  selectToBeginningOfNextWord: ->
    @modifySelection => @cursor.moveToBeginningOfNextWord()

  # Public: Moves the selection down one row.
  addSelectionBelow: ->
    range = (@goalBufferRange ? @getBufferRange()).copy()
    nextRow = range.end.row + 1

    for row in [nextRow..@editSession.getLastBufferRow()]
      range.start.row = row
      range.end.row = row
      clippedRange = @editSession.clipBufferRange(range)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      @editSession.addSelectionForBufferRange(range, goalBufferRange: range, suppressMerge: true)
      break

  # Public: Moves the selection up one row.
  addSelectionAbove: ->
    range = (@goalBufferRange ? @getBufferRange()).copy()
    previousRow = range.end.row - 1

    for row in [previousRow..0]
      range.start.row = row
      range.end.row = row
      clippedRange = @editSession.clipBufferRange(range)

      if range.isEmpty()
        continue if range.end.column > 0 and clippedRange.end.column is 0
      else
        continue if clippedRange.isEmpty()

      @editSession.addSelectionForBufferRange(range, goalBufferRange: range, suppressMerge: true)
      break

  # Public: Replaces text at the current selection.
  #
  # text - A {String} representing the text to add
  # options - A hash containing the following options:
  #           :normalizeIndent - TODO
  #           :select - if `true`, selects the newly added text
  #           :autoIndent - if `true`, indents the newly added text appropriately
  insertText: (text, options={}) ->
    oldBufferRange = @getBufferRange()
    @editSession.destroyFoldsContainingBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    text = @normalizeIndent(text, options) if options.normalizeIndent
    @clear()
    @cursor.needsAutoscroll = @cursor.isLastCursor()
    newBufferRange = @editSession.buffer.change(oldBufferRange, text)
    if options.select
      @setBufferRange(newBufferRange, reverse: wasReversed)
    else
      @cursor.setBufferPosition(newBufferRange.end, skipAtomicTokens: true) if wasReversed

    if options.autoIndent
      if text == '\n'
        @editSession.autoIndentBufferRow(newBufferRange.end.row)
      else if /\S/.test(text)
        @editSession.autoDecreaseIndentForRow(newBufferRange.start.row)

    newBufferRange

  # Public: Indents the selection.
  #
  # options - A hash with one key, `autoIndent`. If `true`, the indentation is 
  #           performed appropriately. Otherwise, {EditSession#getTabText} is used
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

  # Public: If the selection spans multiple rows, indents all of them.
  indentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    for row in [start..end]
      @editSession.buffer.insert([row, 0], @editSession.getTabText()) unless @editSession.buffer.lineLengthForRow(row) == 0

  normalizeIndent: (text, options) ->
    return text unless /\n/.test(text)

    currentBufferRow = @cursor.getBufferRow()
    currentBufferColumn = @cursor.getBufferColumn()
    lines = text.split('\n')
    currentBasis = options.indentBasis ? @editSession.indentLevelForLine(lines[0])
    lines[0] = lines[0].replace(/^\s*/, '') # strip leading space from first line

    normalizedLines = []

    textPrecedingCursor = @editSession.buffer.getTextInRange([[currentBufferRow, 0], [currentBufferRow, currentBufferColumn]])
    insideExistingLine = textPrecedingCursor.match(/\S/)

    if insideExistingLine
      desiredBasis = @editSession.indentationForBufferRow(currentBufferRow)
    else if options.autoIndent
      desiredBasis = @editSession.suggestedIndentForBufferRow(currentBufferRow)
    else
      desiredBasis = @cursor.getIndentLevel()

    for line, i in lines
      if i == 0
        if insideExistingLine
          delta = 0
        else
          delta = desiredBasis - @cursor.getIndentLevel()
      else
        delta = desiredBasis - currentBasis

      normalizedLines.push(@adjustIndentationForLine(line, delta))

    normalizedLines.join('\n')

  adjustIndentationForLine: (line, delta) ->
    currentIndentLevel = @editSession.indentLevelForLine(line)
    desiredIndentLevel = Math.max(0, currentIndentLevel + delta)
    desiredIndentString = @editSession.buildIndentString(desiredIndentLevel)
    line.replace(/^[\t ]*/, desiredIndentString)

  # Public: Performs a backspace, removing the character found behind the selection.
  backspace: ->
    if @isEmpty() and not @editSession.isFoldedAtScreenRow(@cursor.getScreenRow())
      if @cursor.isAtBeginningOfLine() and @editSession.isFoldedAtScreenRow(@cursor.getScreenRow() - 1)
        @selectToBufferPosition([@cursor.getBufferRow() - 1, Infinity])
      else
        @selectLeft()

    @deleteSelectedText()

  # Public: Performs a backspace to the beginning of the current word, removing characters found there.
  backspaceToBeginningOfWord: ->
    @selectToBeginningOfWord() if @isEmpty()
    @deleteSelectedText()

  # Public: Performs a backspace to the beginning of the current line, removing characters found there.
  backspaceToBeginningOfLine: ->
    if @isEmpty() and @cursor.isAtBeginningOfLine()
      @selectLeft()
    else
      @selectToBeginningOfLine()
    @deleteSelectedText()

  # Public: Performs a delete, removing the character found ahead of the cursor position.
  delete: ->
    if @isEmpty()
      if @cursor.isAtEndOfLine() and fold = @editSession.largestFoldStartingAtScreenRow(@cursor.getScreenRow() + 1)
        @selectToBufferPosition(fold.getBufferRange().end)
      else
        @selectRight()
    @deleteSelectedText()

  # Public: Performs a delete to the end of the current word, removing characters found there.
  deleteToEndOfWord: ->
    @selectToEndOfWord() if @isEmpty()
    @deleteSelectedText()

  # Public: Deletes the selected text.
  deleteSelectedText: ->
    bufferRange = @getBufferRange()
    if fold = @editSession.largestFoldContainingBufferRow(bufferRange.end.row)
      includeNewline = bufferRange.start.column == 0 or bufferRange.start.row >= fold.startRow
      bufferRange = bufferRange.union(fold.getBufferRange({ includeNewline }))

    @editSession.buffer.delete(bufferRange) unless bufferRange.isEmpty()
    @cursor?.setBufferPosition(bufferRange.start)

  # Public: Deletes the line.
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
      newSelectedRange = @editSession.getMarkerBufferRange(joinMarker)
      @setBufferRange(newSelectedRange)
      @editSession.destroyMarker(joinMarker)

  outdentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    buffer = @editSession.buffer
    leadingTabRegex = new RegExp("^ {1,#{@editSession.getTabLength()}}|\t")
    for row in [start..end]
      if matchLength = buffer.lineForRow(row).match(leadingTabRegex)?[0].length
        buffer.delete [[row, 0], [row, matchLength]]

  autoIndentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    @editSession.autoIndentBufferRows(start, end)

  # Public: Wraps the selected lines in comments.
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineComments: ->
    @editSession.toggleLineCommentsForBufferRows(@getBufferRowRange()...)

  # Public: Performs a cut operation on the selection, until the end of the line.
  #
  # maintainPasteboard - A {Boolean} indicating TODO
  cutToEndOfLine: (maintainPasteboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainPasteboard)

  # Public: Performs a cut operation on the selection.
  #
  # maintainPasteboard - A {Boolean} indicating TODO
  cut: (maintainPasteboard=false) ->
    @copy(maintainPasteboard)
    @delete()

  # Public: Performs a copy operation on the selection.
  #
  # maintainPasteboard - A {Boolean} indicating TODO
  copy: (maintainPasteboard=false) ->
    return if @isEmpty()
    text = @editSession.buffer.getTextInRange(@getBufferRange())
    if maintainPasteboard
      [currentText, metadata] = pasteboard.read()
      text = currentText + '\n' + text
    else
      metadata = { indentBasis: @editSession.indentationForBufferRow(@getBufferRange().start.row) }

    pasteboard.write(text, metadata)

  # Public: Folds the selection.
  fold: ->
    range = @getBufferRange()
    @editSession.createFold(range.start.row, range.end.row)
    @cursor.setBufferPosition([range.end.row + 1, 0])

  autoIndentText: (text) ->
    @editSession.autoIndentTextAfterBufferPosition(text, @cursor.getBufferPosition())

  autoOutdent: ->
    @editSession.autoOutdentBufferRow(@cursor.getBufferRow())

  modifySelection: (fn) ->
    @retainSelection = true
    @placeTail()
    fn()
    @retainSelection = false

  placeTail: ->
    @editSession.placeMarkerTail(@marker)

  # Public: Identifies if a selection intersects with a given buffer range.
  #
  # bufferRange - A {Range} to check against
  #
  # Returns a {Boolean}.
  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  # Public: Identifies if a selection intersects with another selection.
  #
  # otherSelection - A `Selection` to check against
  #
  # Returns a {Boolean}.
  intersectsWith: (otherSelection) ->
    @getBufferRange().intersectsWith(otherSelection.getBufferRange())

  # Public: Merges two selections together.
  #
  # otherSelection - A `Selection` to merge with
  # options - A hash of options matching those found in {.setBufferRange}
  merge: (otherSelection, options) ->
    @setBufferRange(@getBufferRange().union(otherSelection.getBufferRange()), options)
    if @goalBufferRange and otherSelection.goalBufferRange
      @goalBufferRange = @goalBufferRange.union(otherSelection.goalBufferRange)
    else if otherSelection.goalBufferRange
      @goalBufferRange = otherSelection.goalBufferRange
    otherSelection.destroy()

_.extend Selection.prototype, EventEmitter
