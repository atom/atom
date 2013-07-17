{Range} = require 'telepath'
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

  ### Internal ###

  constructor: ({@cursor, @marker, @editSession, @goalBufferRange}) ->
    @cursor.selection = this
    @marker.on 'changed', => @screenRangeChanged()
    @marker.on 'destroyed', =>
      @destroyed = true
      @editSession.removeSelection(this)
      @trigger 'destroyed' unless @editSession.destroyed

  destroy: ->
    @marker.destroy()

  finalize: ->
    @initialScreenRange = null unless @initialScreenRange?.isEqual(@getScreenRange())
    if @isEmpty()
      @wordwise = false
      @linewise = false

  clearAutoscroll: ->
    @needsAutoscroll = null

  ### Public ###

  # Identifies if the selection is highlighting anything.
  #
  # Returns a {Boolean}.
  isEmpty: ->
    @getBufferRange().isEmpty()

  # Identifies if the ending position of a marker is greater than the starting position.
  #
  # This can happen when, for example, you highlight text "up" in a {Buffer}.
  #
  # Returns a {Boolean}.
  isReversed: ->
    @marker.isReversed()

  # Identifies if the selection is a single line.
  #
  # Returns a {Boolean}.
  isSingleScreenLine: ->
    @getScreenRange().isSingleLine()

  # Retrieves the screen range for the selection.
  #
  # Returns a {Range}.
  getScreenRange: ->
    @marker.getScreenRange()

  # Modifies the screen range for the selection.
  #
  # screenRange - The new {Range} to use
  # options - A hash of options matching those found in {.setBufferRange}
  setScreenRange: (screenRange, options) ->
    @setBufferRange(@editSession.bufferRangeForScreenRange(screenRange), options)

  # Retrieves the buffer range for the selection.
  #
  # Returns a {Range}.
  getBufferRange: ->
    @marker.getBufferRange()

  # Modifies the buffer range for the selection.
  #
  # screenRange - The new {Range} to select
  # options - A hash of options with the following keys:
  #           preserveFolds: if `true`, the fold settings are preserved after the selection moves
  #           autoscroll: if `true`, the {EditSession} scrolls to the new selection
  setBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    @needsAutoscroll = options.autoscroll
    options.reverse ?= @isReversed()
    @editSession.destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
    @modifySelection =>
      @cursor.needsAutoscroll = false if options.autoscroll?
      @marker.setBufferRange(bufferRange, options)

  # Retrieves the starting and ending buffer rows the selection is highlighting.
  #
  # Returns an {Array} of two {Number}s: the starting row, and the ending row.
  getBufferRowRange: ->
    range = @getBufferRange()
    start = range.start.row
    end = range.end.row
    end = Math.max(start, end - 1) if range.end.column == 0
    [start, end]

  # Retrieves the text in the selection.
  #
  # Returns a {String}.
  getText: ->
    @editSession.buffer.getTextInRange(@getBufferRange())

  # Clears the selection, moving the marker to move to the head.
  clear: ->
    @marker.clearTail()

  # Modifies the selection to mark the current word.
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

  # Selects an entire line in the {Buffer}.
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

  # Selects the text from the current cursor position to a given screen position.
  #
  # position - An instance of {Point}, with a given `row` and `column`.
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

  # Selects the text from the current cursor position to a given buffer position.
  #
  # position - An instance of {Point}, with a given `row` and `column`.
  selectToBufferPosition: (position) ->
    @modifySelection => @cursor.setBufferPosition(position)

  # Selects the text one position right of the cursor.
  selectRight: ->
    @modifySelection => @cursor.moveRight()

  # Selects the text one position left of the cursor.
  selectLeft: ->
    @modifySelection => @cursor.moveLeft()

  # Selects all the text one position above the cursor.
  selectUp: ->
    @modifySelection => @cursor.moveUp()

  # Selects all the text one position below the cursor.
  selectDown: ->
    @modifySelection => @cursor.moveDown()

  # Selects all the text from the current cursor position to the top of the buffer.
  selectToTop: ->
    @modifySelection => @cursor.moveToTop()

  # Selects all the text from the current cursor position to the bottom of the buffer.
  selectToBottom: ->
    @modifySelection => @cursor.moveToBottom()

  # Selects all the text in the buffer.
  selectAll: ->
    @setBufferRange(@editSession.buffer.getRange(), autoscroll: false)

  # Selects all the text from the current cursor position to the beginning of the line.
  selectToBeginningOfLine: ->
    @modifySelection => @cursor.moveToBeginningOfLine()

  # Selects all the text from the current cursor position to the end of the line.
  selectToEndOfLine: ->
    @modifySelection => @cursor.moveToEndOfLine()

  # Selects all the text from the current cursor position to the beginning of the word.
  selectToBeginningOfWord: ->
    @modifySelection => @cursor.moveToBeginningOfWord()

  # Selects all the text from the current cursor position to the end of the word.
  selectToEndOfWord: ->
    @modifySelection => @cursor.moveToEndOfWord()

  # Selects all the text from the current cursor position to the beginning of the next word.
  selectToBeginningOfNextWord: ->
    @modifySelection => @cursor.moveToBeginningOfNextWord()

  # Moves the selection down one row.
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

  # Moves the selection up one row.
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

  # Replaces text at the current selection.
  #
  # text - A {String} representing the text to add
  # options - A hash containing the following options:
  #           select: if `true`, selects the newly added text
  #           autoIndent: if `true`, indents all inserted text appropriately
  #           autoIndentNewline: if `true`, indent newline appropriately
  #           autoDecreaseIndent: if `true`, decreases indent level appropriately (for example, when a closing bracket is inserted)

  insertText: (text, options={}) ->
    oldBufferRange = @getBufferRange()
    @editSession.destroyFoldsContainingBufferRow(oldBufferRange.end.row)
    wasReversed = @isReversed()
    @clear()
    @cursor.needsAutoscroll = @cursor.isLastCursor()

    if options.indentBasis? and not options.autoIndent
      text = @normalizeIndents(text, options.indentBasis)

    newBufferRange = @editSession.buffer.change(oldBufferRange, text)
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

  # Indents the selection.
  #
  # options - A hash with one key, `autoIndent`. If `true`, the indentation is
  #           performed appropriately. Otherwise, {EditSession.getTabText} is used
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

  # If the selection spans multiple rows, indents all of them.
  indentSelectedRows: ->
    [start, end] = @getBufferRowRange()
    for row in [start..end]
      @editSession.buffer.insert([row, 0], @editSession.getTabText()) unless @editSession.buffer.lineLengthForRow(row) == 0

  setIndentationForLine: (line, indentLevel) ->
    desiredIndentLevel = Math.max(0, indentLevel)
    desiredIndentString = @editSession.buildIndentString(desiredIndentLevel)
    line.replace(/^[\t ]*/, desiredIndentString)

  # Performs a backspace, removing the character found behind the selection.
  backspace: ->
    @selectLeft() if @isEmpty() and not @editSession.isFoldedAtScreenRow(@cursor.getScreenRow())
    @deleteSelectedText()

  # Performs a backspace to the beginning of the current word, removing characters found there.
  backspaceToBeginningOfWord: ->
    @selectToBeginningOfWord() if @isEmpty()
    @deleteSelectedText()

  # Performs a backspace to the beginning of the current line, removing characters found there.
  backspaceToBeginningOfLine: ->
    if @isEmpty() and @cursor.isAtBeginningOfLine()
      @selectLeft()
    else
      @selectToBeginningOfLine()
    @deleteSelectedText()

  # Performs a delete, removing the character found ahead of the cursor position.
  delete: ->
    if @isEmpty()
      if @cursor.isAtEndOfLine() and fold = @editSession.largestFoldStartingAtScreenRow(@cursor.getScreenRow() + 1)
        @selectToBufferPosition(fold.getBufferRange().end)
      else
        @selectRight()
    @deleteSelectedText()

  # Performs a delete to the end of the current word, removing characters found there.
  deleteToEndOfWord: ->
    @selectToEndOfWord() if @isEmpty()
    @deleteSelectedText()

  # Deletes the selected text.
  deleteSelectedText: ->
    bufferRange = @getBufferRange()
    if bufferRange.isEmpty() and fold = @editSession.largestFoldContainingBufferRow(bufferRange.start.row)
      bufferRange = bufferRange.union(fold.getBufferRange(includeNewline: true))
    @editSession.buffer.delete(bufferRange) unless bufferRange.isEmpty()
    @cursor?.setBufferPosition(bufferRange.start)

  # Deletes the line.
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

  # Joins the current line with the one below it.
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

  # Wraps the selected lines in comments.
  #
  # Returns an {Array} of the commented {Ranges}.
  toggleLineComments: ->
    @editSession.toggleLineCommentsForBufferRows(@getBufferRowRange()...)

  # Performs a cut operation on the selection, until the end of the line.
  #
  # maintainPasteboard - A {Boolean} indicating TODO
  cutToEndOfLine: (maintainPasteboard) ->
    @selectToEndOfLine() if @isEmpty()
    @cut(maintainPasteboard)

  # Performs a cut operation on the selection.
  #
  # maintainPasteboard - A {Boolean} indicating TODO
  cut: (maintainPasteboard=false) ->
    @copy(maintainPasteboard)
    @delete()

  # Performs a copy operation on the selection.
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

  # Folds the selection.
  fold: ->
    range = @getBufferRange()
    @editSession.createFold(range.start.row, range.end.row)
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

  # Identifies if a selection intersects with a given buffer range.
  #
  # bufferRange - A {Range} to check against
  #
  # Returns a {Boolean}.
  intersectsBufferRange: (bufferRange) ->
    @getBufferRange().intersectsWith(bufferRange)

  # Identifies if a selection intersects with another selection.
  #
  # otherSelection - A `Selection` to check against
  #
  # Returns a {Boolean}.
  intersectsWith: (otherSelection) ->
    @getBufferRange().intersectsWith(otherSelection.getBufferRange())

  # Merges two selections together.
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

  ### Internal ###

  screenRangeChanged: ->
    screenRange = @getScreenRange()
    @trigger 'screen-range-changed', screenRange

_.extend Selection.prototype, EventEmitter
