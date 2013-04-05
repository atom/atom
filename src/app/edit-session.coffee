Point = require 'point'
Buffer = require 'text-buffer'
LanguageMode = require 'language-mode'
DisplayBuffer = require 'display-buffer'
Cursor = require 'cursor'
Selection = require 'selection'
EventEmitter = require 'event-emitter'
Subscriber = require 'subscriber'
Range = require 'range'
_ = require 'underscore'
fs = require 'fs-utils'

module.exports =
class EditSession
  registerDeserializer(this)

  @deserialize: (state) ->
    if fs.exists(state.buffer)
      session = project.buildEditSession(state.buffer)
    else
      console.warn "Could not build edit session for path '#{state.buffer}' because that file no longer exists" if state.buffer
      session = project.buildEditSession(null)
    session.setScrollTop(state.scrollTop)
    session.setScrollLeft(state.scrollLeft)
    session.setCursorScreenPosition(state.cursorScreenPosition)
    session

  scrollTop: 0
  scrollLeft: 0
  languageMode: null
  displayBuffer: null
  cursors: null
  selections: null
  softTabs: true
  softWrap: false

  constructor: ({@project, @buffer, tabLength, softTabs, @softWrap }) ->
    @softTabs = @buffer.usesSoftTabs() ? softTabs ? true
    @languageMode = new LanguageMode(this, @buffer.getExtension())
    @displayBuffer = new DisplayBuffer(@buffer, { @languageMode, tabLength })
    @cursors = []
    @selections = []
    @addCursorAtScreenPosition([0, 0])

    @buffer.retain()
    @subscribe @buffer, "path-changed", =>
      @project.setPath(fs.directory(@getPath())) unless @project.getPath()?
      @trigger "title-changed"
      @trigger "path-changed"
    @subscribe @buffer, "contents-conflicted", => @trigger "contents-conflicted"
    @subscribe @buffer, "markers-updated", => @mergeCursors()
    @subscribe @buffer, "modified-status-changed", => @trigger "modified-status-changed"

    @preserveCursorPositionOnBufferReload()

    @subscribe @displayBuffer, "changed", (e) =>
      @trigger 'screen-lines-changed', e

    @subscribe syntax, 'grammars-loaded', => @reloadGrammar()

  getViewClass: ->
    require 'editor'

  getTitle: ->
    if path = @getPath()
      fs.base(path)
    else
      'untitled'

  getLongTitle: ->
    if path = @getPath()
      fileName = fs.base(path)
      directory = fs.base(fs.directory(path))
      "#{fileName} - #{directory}"
    else
      'untitled'

  destroy: ->
    return if @destroyed
    @destroyed = true
    @unsubscribe()
    @buffer.release()
    selection.destroy() for selection in @getSelections()
    @displayBuffer.destroy()
    @project?.removeEditSession(this)
    @trigger 'destroyed'
    @off()

  serialize: ->
    deserializer: 'EditSession'
    buffer: @buffer.getPath()
    scrollTop: @getScrollTop()
    scrollLeft: @getScrollLeft()
    cursorScreenPosition: @getCursorScreenPosition().serialize()

  copy: ->
    EditSession.deserialize(@serialize(), @project)

  isEqual: (other) ->
    return false unless other instanceof EditSession
    @buffer == other.buffer and
      @scrollTop == other.getScrollTop() and
      @scrollLeft == other.getScrollLeft() and
      @getCursorScreenPosition().isEqual(other.getCursorScreenPosition())

  setVisible: (visible) -> @displayBuffer.setVisible(visible)

  setScrollTop: (@scrollTop) ->
  getScrollTop: -> @scrollTop

  setScrollLeft: (@scrollLeft) ->
  getScrollLeft: -> @scrollLeft

  setSoftWrapColumn: (@softWrapColumn) -> @displayBuffer.setSoftWrapColumn(@softWrapColumn)
  setSoftTabs: (@softTabs) ->

  getSoftWrap: -> @softWrap
  setSoftWrap: (@softWrap) ->

  getTabText: -> @buildIndentString(1)

  getTabLength: -> @displayBuffer.getTabLength()
  setTabLength: (tabLength) -> @displayBuffer.setTabLength(tabLength)

  clipBufferPosition: (bufferPosition) ->
    @buffer.clipPosition(bufferPosition)

  indentationForBufferRow: (bufferRow) ->
    @indentLevelForLine(@lineForBufferRow(bufferRow))

  setIndentationForBufferRow: (bufferRow, newLevel) ->
    currentLevel = @indentationForBufferRow(bufferRow)
    currentIndentString = @buildIndentString(currentLevel)
    newIndentString = @buildIndentString(newLevel)
    @buffer.change([[bufferRow, 0], [bufferRow, currentIndentString.length]], newIndentString)

  indentLevelForLine: (line) ->
    if match = line.match(/^[\t ]+/)
      leadingWhitespace = match[0]
      tabCount = leadingWhitespace.match(/\t/g)?.length ? 0
      spaceCount = leadingWhitespace.match(/[ ]/g)?.length ? 0
      tabCount + (spaceCount / @getTabLength())
    else
      0

  buildIndentString: (number) ->
    if @softTabs
      _.multiplyString(" ", number * @getTabLength())
    else
      _.multiplyString("\t", Math.floor(number))

  save: -> @buffer.save()
  saveAs: (path) -> @buffer.saveAs(path)
  # Public: Retrieves the current buffer's file extension.
  #
  # Returns a {String}.
  getFileExtension: -> @buffer.getExtension()
  # Public: Retrieves the current buffer's file path.
  #
  # Returns a {String}.
  getPath: -> @buffer.getPath()
  getUri: -> @getPath()
  isBufferRowBlank: (bufferRow) -> @buffer.isRowBlank(bufferRow)
  nextNonBlankBufferRow: (bufferRow) -> @buffer.nextNonBlankRow(bufferRow)
  getEofBufferPosition: -> @buffer.getEofPosition()
  getLastBufferRow: -> @buffer.getLastRow()
  bufferRangeForBufferRow: (row, options) -> @buffer.rangeForRow(row, options)
  lineForBufferRow: (row) -> @buffer.lineForRow(row)
  lineLengthForBufferRow: (row) -> @buffer.lineLengthForRow(row)
  scanInRange: (args...) -> @buffer.scanInRange(args...)
  backwardsScanInRange: (args...) -> @buffer.backwardsScanInRange(args...)
  isModified: -> @buffer.isModified()
  hasEditors: -> @buffer.hasEditors()

  screenPositionForBufferPosition: (bufferPosition, options) -> @displayBuffer.screenPositionForBufferPosition(bufferPosition, options)
  bufferPositionForScreenPosition: (screenPosition, options) -> @displayBuffer.bufferPositionForScreenPosition(screenPosition, options)
  screenRangeForBufferRange: (range) -> @displayBuffer.screenRangeForBufferRange(range)
  bufferRangeForScreenRange: (range) -> @displayBuffer.bufferRangeForScreenRange(range)
  clipScreenPosition: (screenPosition, options) -> @displayBuffer.clipScreenPosition(screenPosition, options)
  # Public: Gets the line for the given screen row.
  #
  # screenRow - A {Number} indicating the screen row.
  #
  # Returns a {String}.
  lineForScreenRow: (row) -> @displayBuffer.lineForRow(row)
  # Public: Gets the lines for the given screen row boundaries.
  #
  # start - A {Number} indicating the beginning screen row.
  # start - A {Number} indicating the ending screen row.
  #
  # Returns an {Array} of {String}s.
  linesForScreenRows: (start, end) -> @displayBuffer.linesForRows(start, end)
  # Public: Gets the number of screen rows.
  #
  # Returns a {Number}.
  screenLineCount: -> @displayBuffer.lineCount()
  # Public: Gets the length of the longest screen line.
  #
  # Returns a {Number}.
  maxScreenLineLength: -> @displayBuffer.maxLineLength()
  # Public: Gets the text in the last screen row.
  #
  # Returns a {String}.
  getLastScreenRow: -> @displayBuffer.getLastRow()
  bufferRowsForScreenRows: (startRow, endRow) -> @displayBuffer.bufferRowsForScreenRows(startRow, endRow)
  scopesForBufferPosition: (bufferPosition) -> @displayBuffer.scopesForBufferPosition(bufferPosition)
  getCursorScopes: -> @getCursor().getScopes()
  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)

  shouldAutoIndent: ->
    config.get("editor.autoIndent")

  shouldAutoIndentPastedText: ->
    config.get("editor.autoIndentOnPaste")
  # Public: Inserts text at the current cursor positions.
  #
  # text - A {String} representing the text to insert.
  # options - A set of options equivalent to {Selection.insertText}.
  insertText: (text, options={}) ->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.insertText(text, options)

  # Public: Inserts a new line at the current cursor positions.
  insertNewline: ->
    @insertText('\n')

  # Public: Inserts a new line below the current cursor positions.
  insertNewlineBelow: ->
    @transact =>
      @moveCursorToEndOfLine()
      @insertNewline()

  # Public: Inserts a new line above the current cursor positions.
  insertNewlineAbove: ->
    @transact =>
      onFirstLine = @getCursorBufferPosition().row is 0
      @moveCursorToBeginningOfLine()
      @moveCursorLeft()
      @insertNewline()
      @moveCursorUp() if onFirstLine

  # Public: Indents the current line.
  #
  # options - A set of options equivalent to {Selection.indent}.
  indent: (options={})->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  # Public: Performs a backspace, removing the character found behind the cursor position.
  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  # Public: Performs a backspace to the beginning of the current word, removing characters found there.
  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

  # Public: Performs a backspace to the beginning of the current line, removing characters found there.
  backspaceToBeginningOfLine: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfLine()

  # Public: Performs a delete, removing the character found behind the cursor position.
  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  # Public: Performs a delete to the end of the current word, removing characters found there.
  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  # Public: Performs a delete to the end of the current line, removing characters found there.
  deleteLine: ->
    @mutateSelectedText (selection) -> selection.deleteLine()

  # Public: Indents the selected rows.
  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  # Public: Outdents the selected rows.
  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  toggleLineCommentsInSelection: ->
    @mutateSelectedText (selection) -> selection.toggleLineComments()

  autoIndentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.autoIndentSelectedRows()

  normalizeTabsInBufferRange: (bufferRange) ->
    return unless @softTabs
    @scanInRange /\t/, bufferRange, (match, range, {replace}) => replace(@getTabText())

  # Public: Performs a cut to the end of the current line. 
  #
  # Characters are removed, but the text remains in the clipboard.
  cutToEndOfLine: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfLine(maintainPasteboard)
      maintainPasteboard = true

  # Public: Cuts the selected text.
  cutSelectedText: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cut(maintainPasteboard)
      maintainPasteboard = true

  # Public: Copies the selected text.
  copySelectedText: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.copy(maintainPasteboard)
      maintainPasteboard = true

  # Public: Pastes the text in the clipboard.
  #
  # options - A set of options equivalent to {Selection.insertText}.
  pasteText: (options={}) ->
    options.normalizeIndent ?= true
    options.autoIndent ?= @shouldAutoIndentPastedText()

    [text, metadata] = pasteboard.read()
    _.extend(options, metadata) if metadata

    @insertText(text, options)

  # Public: Undos the last {Buffer} change.
  undo: ->
    @buffer.undo(this)

  # Public: Redos the last {Buffer} change.
  redo: ->
    @buffer.redo(this)

  transact: (fn) ->
    isNewTransaction = @buffer.transact()
    oldSelectedRanges = @getSelectedBufferRanges()
    @pushOperation
      undo: (editSession) ->
        editSession?.setSelectedBufferRanges(oldSelectedRanges)
    if fn
      result = fn()
      @commit() if isNewTransaction
      result

  commit: ->
    newSelectedRanges = @getSelectedBufferRanges()
    @pushOperation
      redo: (editSession) ->
        editSession?.setSelectedBufferRanges(newSelectedRanges)
    @buffer.commit()

  abort: ->
    @buffer.abort()

  # Public: Folds all the rows.
  foldAll: ->
    @displayBuffer.foldAll()

  # Public: Unfolds all the rows.
  unfoldAll: ->
    @displayBuffer.unfoldAll()

  # Public: Folds the current row.
  foldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @foldBufferRow(bufferRow)

  foldBufferRow: (bufferRow) ->
    @displayBuffer.foldBufferRow(bufferRow)

  # Public: Unfolds the current row.
  unfoldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @unfoldBufferRow(bufferRow)

  unfoldBufferRow: (bufferRow) ->
    @displayBuffer.unfoldBufferRow(bufferRow)

  foldSelection: ->
    selection.fold() for selection in @getSelections()

  createFold: (startRow, endRow) ->
    @displayBuffer.createFold(startRow, endRow)

  destroyFoldsContainingBufferRow: (bufferRow) ->
    @displayBuffer.destroyFoldsContainingBufferRow(bufferRow)

  destroyFoldsIntersectingBufferRange: (bufferRange) ->
    for row in [bufferRange.start.row..bufferRange.end.row]
      @destroyFoldsContainingBufferRow(row)

  destroyFold: (foldId) ->
    fold = @displayBuffer.foldsById[foldId]
    fold.destroy()
    @setCursorBufferPosition([fold.startRow, 0])

  # Public: Determines if the given row that the cursor is at is folded.
  #
  # Returns `true` if the row is folded, `false` otherwise.
  isFoldedAtCursorRow: ->
    @isFoldedAtScreenRow(@getCursorScreenRow())
  # Public: Determines if the given buffer row is folded.
  #
  # screenRow - A {Number} indicating the buffer row.
  # Returns `true` if the buffer row is folded, `false` otherwise.
  isFoldedAtBufferRow: (bufferRow) ->
    screenRow = @screenPositionForBufferPosition([bufferRow]).row
    @isFoldedAtScreenRow(screenRow)
  # Public: Determines if the given screen row is folded.
  #
  # screenRow - A {Number} indicating the screen row.
  # Returns `true` if the screen row is folded, `false` otherwise.
  isFoldedAtScreenRow: (screenRow) ->
    @lineForScreenRow(screenRow)?.fold?

  largestFoldContainingBufferRow: (bufferRow) ->
    @displayBuffer.largestFoldContainingBufferRow(bufferRow)

  largestFoldStartingAtScreenRow: (screenRow) ->
    @displayBuffer.largestFoldStartingAtScreenRow(screenRow)

  suggestedIndentForBufferRow: (bufferRow) ->
    @languageMode.suggestedIndentForBufferRow(bufferRow)

  autoIndentBufferRows: (startRow, endRow) ->
    @languageMode.autoIndentBufferRows(startRow, endRow)

  autoIndentBufferRow: (bufferRow) ->
    @languageMode.autoIndentBufferRow(bufferRow)

  autoIncreaseIndentForBufferRow: (bufferRow) ->
    @languageMode.autoIncreaseIndentForBufferRow(bufferRow)

  autoDecreaseIndentForRow: (bufferRow) ->
    @languageMode.autoDecreaseIndentForBufferRow(bufferRow)

  toggleLineCommentsForBufferRows: (start, end) ->
    @languageMode.toggleLineCommentsForBufferRows(start, end)

  # Public: Moves the selected line up one row.
  moveLineUp: ->
    selection = @getSelectedBufferRange()
    return if selection.start.row is 0
    lastRow = @buffer.getLastRow()
    return if selection.isEmpty() and selection.start.row is lastRow and @buffer.getLastLine() is ''

    @transact =>
      foldedRows = []
      rows = [selection.start.row..selection.end.row]
      if selection.start.row isnt selection.end.row and selection.end.column is 0
        rows.pop() unless @isFoldedAtBufferRow(selection.end.row)
      for row in rows
        screenRow = @screenPositionForBufferPosition([row]).row
        if @isFoldedAtScreenRow(screenRow)
          bufferRange = @bufferRangeForScreenRange([[screenRow], [screenRow + 1]])
          startRow = bufferRange.start.row
          endRow = bufferRange.end.row - 1
          foldedRows.push(endRow - 1)
        else
          startRow = row
          endRow = row

        endPosition = Point.min([endRow + 1], @buffer.getEofPosition())
        lines = @buffer.getTextInRange([[startRow], endPosition])
        if endPosition.row is lastRow and endPosition.column > 0 and not @buffer.lineEndingForRow(endPosition.row)
          lines = "#{lines}\n"
        @buffer.deleteRows(startRow, endRow)
        @buffer.insert([startRow - 1], lines)

      @foldBufferRow(foldedRow) for foldedRow in foldedRows

      @setSelectedBufferRange(selection.translate([-1]), preserveFolds: true)

  # Public: Moves the selected line down one row.
  moveLineDown: ->
    selection = @getSelectedBufferRange()
    lastRow = @buffer.getLastRow()
    return if selection.end.row is lastRow
    return if selection.end.row is lastRow - 1 and @buffer.getLastLine() is ''

    @transact =>
      foldedRows = []
      rows = [selection.end.row..selection.start.row]
      if selection.start.row isnt selection.end.row and selection.end.column is 0
        rows.shift() unless @isFoldedAtBufferRow(selection.end.row)
      for row in rows
        screenRow = @screenPositionForBufferPosition([row]).row
        if @isFoldedAtScreenRow(screenRow)
          bufferRange = @bufferRangeForScreenRange([[screenRow], [screenRow + 1]])
          startRow = bufferRange.start.row
          endRow = bufferRange.end.row - 1
          foldedRows.push(endRow + 1)
        else
          startRow = row
          endRow = row

        if endRow + 1 is lastRow
          endPosition = [endRow, @buffer.lineLengthForRow(endRow)]
        else
          endPosition = [endRow + 1]
        lines = @buffer.getTextInRange([[startRow], endPosition])
        @buffer.deleteRows(startRow, endRow)
        insertPosition = Point.min([startRow + 1], @buffer.getEofPosition())
        if insertPosition.row is @buffer.getLastRow() and insertPosition.column > 0
          lines = "\n#{lines}"
        @buffer.insert(insertPosition, lines)

      @foldBufferRow(foldedRow) for foldedRow in foldedRows

      @setSelectedBufferRange(selection.translate([1]), preserveFolds: true)

  duplicateLine: ->
    return unless @getSelection().isEmpty()

    @transact =>
      cursorPosition = @getCursorBufferPosition()
      cursorRowFolded = @isFoldedAtCursorRow()
      if cursorRowFolded
        screenRow = @screenPositionForBufferPosition(cursorPosition).row
        bufferRange = @bufferRangeForScreenRange([[screenRow], [screenRow + 1]])
      else
        bufferRange = new Range([cursorPosition.row], [cursorPosition.row + 1])

      insertPosition = new Point(bufferRange.end.row)
      if insertPosition.row > @buffer.getLastRow()
        @unfoldCurrentRow() if cursorRowFolded
        @buffer.append("\n#{@getTextInBufferRange(bufferRange)}")
        @foldCurrentRow() if cursorRowFolded
      else
        @buffer.insert(insertPosition, @getTextInBufferRange(bufferRange))

      @setCursorScreenPosition(@getCursorScreenPosition().translate([1]))
      @foldCurrentRow() if cursorRowFolded

  mutateSelectedText: (fn) ->
    @transact => fn(selection) for selection in @getSelections()

  replaceSelectedText: (options={}, fn) ->
    {selectWordIfEmpty} = options
    @mutateSelectedText (selection) =>
      range = selection.getBufferRange()
      if selectWordIfEmpty and selection.isEmpty()
        selection.selectWord()
      text = selection.getText()
      selection.delete()
      selection.insertText(fn(text))
      selection.setBufferRange(range)

  pushOperation: (operation) ->
    @buffer.pushOperation(operation, this)

  markScreenRange: (args...) ->
    @displayBuffer.markScreenRange(args...)

  markBufferRange: (args...) ->
    @displayBuffer.markBufferRange(args...)

  markScreenPosition: (args...) ->
    @displayBuffer.markScreenPosition(args...)

  markBufferPosition: (args...) ->
    @displayBuffer.markBufferPosition(args...)

  destroyMarker: (args...) ->
    @displayBuffer.destroyMarker(args...)

  getMarkerCount: ->
    @buffer.getMarkerCount()

  getMarkerScreenRange: (args...) ->
    @displayBuffer.getMarkerScreenRange(args...)

  setMarkerScreenRange: (args...) ->
    @displayBuffer.setMarkerScreenRange(args...)

  getMarkerBufferRange: (args...) ->
    @displayBuffer.getMarkerBufferRange(args...)

  setMarkerBufferRange: (args...) ->
    @displayBuffer.setMarkerBufferRange(args...)

  getMarkerScreenPosition: (args...) ->
    @displayBuffer.getMarkerScreenPosition(args...)

  getMarkerBufferPosition: (args...) ->
    @displayBuffer.getMarkerBufferPosition(args...)

  getMarkerHeadScreenPosition: (args...) ->
    @displayBuffer.getMarkerHeadScreenPosition(args...)

  setMarkerHeadScreenPosition: (args...) ->
    @displayBuffer.setMarkerHeadScreenPosition(args...)

  getMarkerHeadBufferPosition: (args...) ->
    @displayBuffer.getMarkerHeadBufferPosition(args...)

  setMarkerHeadBufferPosition: (args...) ->
    @displayBuffer.setMarkerHeadBufferPosition(args...)

  getMarkerTailScreenPosition: (args...) ->
    @displayBuffer.getMarkerTailScreenPosition(args...)

  setMarkerTailScreenPosition: (args...) ->
    @displayBuffer.setMarkerTailScreenPosition(args...)

  getMarkerTailBufferPosition: (args...) ->
    @displayBuffer.getMarkerTailBufferPosition(args...)

  setMarkerTailBufferPosition: (args...) ->
    @displayBuffer.setMarkerTailBufferPosition(args...)

  observeMarker: (args...) ->
    @displayBuffer.observeMarker(args...)

  placeMarkerTail: (args...) ->
    @displayBuffer.placeMarkerTail(args...)

  clearMarkerTail: (args...) ->
    @displayBuffer.clearMarkerTail(args...)

  isMarkerReversed: (args...) ->
    @displayBuffer.isMarkerReversed(args...)

  # Public: Returns `true` if there are multiple cursors in the edit session.
  #
  # Returns a {Boolean}.
  hasMultipleCursors: ->
    @getCursors().length > 1

  # Public: Retrieves an array of all the cursors.
  #
  # Returns a {[Cursor]}.
  getCursors: -> new Array(@cursors...)

  # Public: Retrieves a single cursor
  #
  # Returns a {Cursor}.
  getCursor: ->
    _.last(@cursors)

  # Public: Adds a cursor at the provided `screenPosition`.
  #
  # screenPosition - An {Array} of two numbers: the screen row, and the screen column.
  #
  # Returns the new {Cursor}.
  addCursorAtScreenPosition: (screenPosition) ->
    marker = @markScreenPosition(screenPosition, invalidationStrategy: 'never')
    @addSelection(marker).cursor

  # Public: Adds a cursor at the provided `bufferPosition`.
  #
  # bufferPosition - An {Array} of two numbers: the buffer row, and the buffer column.
  #
  # Returns the new {Cursor}.
  addCursorAtBufferPosition: (bufferPosition) ->
    marker = @markBufferPosition(bufferPosition, invalidationStrategy: 'never')
    @addSelection(marker).cursor

  addCursor: (marker) ->
    cursor = new Cursor(editSession: this, marker: marker)
    @cursors.push(cursor)
    @trigger 'cursor-added', cursor
    cursor

  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  addSelection: (marker, options={}) ->
    unless options.preserveFolds
      @destroyFoldsIntersectingBufferRange(@getMarkerBufferRange(marker))
    cursor = @addCursor(marker)
    selection = new Selection({editSession: this, marker, cursor})
    @selections.push(selection)
    selectionBufferRange = selection.getBufferRange()
    @mergeIntersectingSelections()
    if selection.destroyed
      for selection in @getSelections()
        if selection.intersectsBufferRange(selectionBufferRange)
          return selection
    else
      @trigger 'selection-added', selection
      selection

  addSelectionForBufferRange: (bufferRange, options={}) ->
    options = _.defaults({invalidationStrategy: 'never'}, options)
    marker = @markBufferRange(bufferRange, options)
    @addSelection(marker)

  setSelectedBufferRange: (bufferRange, options) ->
    @setSelectedBufferRanges([bufferRange], options)

  setSelectedBufferRanges: (bufferRanges, options={}) ->
    throw new Error("Passed an empty array to setSelectedBufferRanges") unless bufferRanges.length

    selections = @getSelections()
    selection.destroy() for selection in selections[bufferRanges.length...]

    for bufferRange, i in bufferRanges
      bufferRange = Range.fromObject(bufferRange)
      if selections[i]
        selections[i].setBufferRange(bufferRange, options)
      else
        @addSelectionForBufferRange(bufferRange, options)
    @mergeIntersectingSelections(options)

  # Public: Unselects a given selection.
  #
  # selection - The {Selection} to remove.
  removeSelection: (selection) ->
    _.remove(@selections, selection)

  # Public: Clears every selection. TODO
  clearSelections: ->
    lastSelection = @getLastSelection()
    for selection in @getSelections() when selection != lastSelection
      selection.destroy()
    lastSelection.clear()

  # Public: Clears every selection.  TODO
  clearAllSelections: ->
    selection.destroy() for selection in @getSelections()

  getSelections: -> new Array(@selections...)

  getSelection: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  getLastSelection: ->
    _.last(@selections)

  getSelectionsOrderedByBufferPosition: ->
    @getSelections().sort (a, b) ->
      aRange = a.getBufferRange()
      bRange = b.getBufferRange()
      aRange.end.compare(bRange.end)

  getLastSelectionInBuffer: ->
    _.last(@getSelectionsOrderedByBufferPosition())

  selectionIntersectsBufferRange: (bufferRange) ->
    _.any @getSelections(), (selection) ->
      selection.intersectsBufferRange(bufferRange)
  # Public: Moves every cursor to a given screen position.
  #
  # position - An {Array} of two numbers: the screen row, and the screen column.
  # options - An object with properties based on {Cursor.changePosition}
  #
  setCursorScreenPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)
  # Public: Gets the current screen position.
  #
  # Returns an {Array} of two numbers: the screen row, and the screen column.
  getCursorScreenPosition: ->
    @getCursor().getScreenPosition()
  # Public: Gets the current cursor's screen row.
  #
  # Returns the screen row.
  getCursorScreenRow: ->
    @getCursor().getScreenRow()
  # Public: Moves every cursor to a given buffer position.
  #
  # position - An {Array} of two numbers: the buffer row, and the buffer column.
  # options - An object with properties based on {Cursor.changePosition}
  #
  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)
  # Public: Gets the current buffer position.
  #
  # Returns an {Array} of two numbers: the buffer row, and the buffer column.
  getCursorBufferPosition: ->
    @getCursor().getBufferPosition()

  getSelectedScreenRange: ->
    @getLastSelection().getScreenRange()

  getSelectedBufferRange: ->
    @getLastSelection().getBufferRange()

  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelectionsOrderedByBufferPosition()
  # Public: Gets the currently selected text.
  #
  # Returns a {String}.
  getSelectedText: ->
    @getLastSelection().getText()

  getTextInBufferRange: (range) ->
    @buffer.getTextInRange(range)

  getCurrentParagraphBufferRange: ->
    @getCursor().getCurrentParagraphBufferRange()
  # Public: Gets the word located under the cursor.
  #
  # options - An object with properties based on {Cursor.getBeginningOfCurrentWordBufferPosition}.
  #
  # Returns a {String}.
  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getCursor().getCurrentWordBufferRange(options))

  # Public: Moves every cursor up one row.
  moveCursorUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount)

  # Public: Moves every cursor down one row.
  moveCursorDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount)

  # Public: Moves every cursor left one column.
  moveCursorLeft: ->
    @moveCursors (cursor) -> cursor.moveLeft()

  # Public: Moves every cursor right one column.
  moveCursorRight: ->
    @moveCursors (cursor) -> cursor.moveRight()

  # Public: Moves every cursor to the top of the buffer.
  moveCursorToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  # Public: Moves every cursor to the bottom of the buffer.
  moveCursorToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  # Public: Moves every cursor to the beginning of the line.
  moveCursorToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  # Public: Moves every cursor to the first non-whitespace character of the line.
  moveCursorToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  # Public: Moves every cursor to the end of the line.
  moveCursorToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  moveCursorToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  moveCursorToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  # Public: Selects the text from the current cursor position to a given position.
  #
  # position - An instance of {Point}, with a given `row` and `column`.
  selectToScreenPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position)
    @mergeIntersectingSelections(reverse: lastSelection.isReversed())
  # Public: Selects the text one position right of the cursor.
  selectRight: ->
    @expandSelectionsForward (selection) => selection.selectRight()
  # Public: Selects the text one position left of the cursor.
  selectLeft: ->
    @expandSelectionsBackward (selection) => selection.selectLeft()

  # Public: Selects all the text one position above the cursor.
  selectUp: ->
    @expandSelectionsBackward (selection) => selection.selectUp()

  # Public: Selects all the text one position below the cursor.
  selectDown: ->
    @expandSelectionsForward (selection) => selection.selectDown()

  # Public: Selects all the text from the current cursor position to the top of the buffer.
  selectToTop: ->
    @expandSelectionsBackward (selection) => selection.selectToTop()

  # Public: Selects all the text in the buffer.
  selectAll: ->
    @expandSelectionsForward (selection) => selection.selectAll()

  # Public: Selects all the text from the current cursor position to the bottom of the buffer.
  selectToBottom: ->
    @expandSelectionsForward (selection) => selection.selectToBottom()

  # Public: Selects all the text from the current cursor position to the beginning of the line.
  selectToBeginningOfLine: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfLine()

  # Public: Selects all the text from the current cursor position to the end of the line.
  selectToEndOfLine: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfLine()

  # Public: Selects the current line.
  selectLine: ->
    @expandSelectionsForward (selection) => selection.selectLine()

  # Public: Transposes the current text selections.
  #
  # This only works if there is more than one selection. Each selection is transferred
  # to the position of the selection after it. The last selection is transferred to the
  # position of the first.
  transpose: ->
    @mutateSelectedText (selection) =>
      if selection.isEmpty()
        selection.selectRight()
        text = selection.getText()
        selection.delete()
        selection.cursor.moveLeft()
        selection.insertText text
      else
        selection.insertText selection.getText().split('').reverse().join('')

  # Public: Turns the current selection into upper case.
  upperCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toUpperCase()

  # Public: Turns the current selection into lower case.
  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toLowerCase()

  expandLastSelectionOverLine: ->
    @getLastSelection().expandOverLine()

  # Public: Selects all the text from the current cursor position to the beginning of the word.
  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfWord()

  # Public: Selects all the text from the current cursor position to the end of the word.
  selectToEndOfWord: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfWord()

  # Public: Selects the current word.
  selectWord: ->
    @expandSelectionsForward (selection) => selection.selectWord()

  expandLastSelectionOverWord: ->
    @getLastSelection().expandOverWord()

  selectMarker: (id) ->
    if bufferRange = @getMarkerBufferRange(id)
      @setSelectedBufferRange(bufferRange)
      true
    else
      false

  markersForBufferPosition: (bufferPosition) ->
    @buffer.markersForPosition(bufferPosition)

  mergeCursors: ->
    positions = []
    for cursor in @getCursors()
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.destroy()
      else
        positions.push(position)

  expandSelectionsForward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections()

  expandSelectionsBackward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections(reverse: true)

  finalizeSelections: ->
    selection.finalize() for selection in @getSelections()

  mergeIntersectingSelections: (options) ->
    for selection in @getSelections()
      otherSelections = @getSelections()
      _.remove(otherSelections, selection)
      for otherSelection in otherSelections
        if selection.intersectsWith(otherSelection)
          selection.merge(otherSelection, options)
          @mergeIntersectingSelections(options)
          return

  inspect: ->
    JSON.stringify @serialize()

  preserveCursorPositionOnBufferReload: ->
    cursorPosition = null
    @subscribe @buffer, "will-reload", =>
      cursorPosition = @getCursorBufferPosition()
    @subscribe @buffer, "reloaded", =>
      @setCursorBufferPosition(cursorPosition) if cursorPosition
      cursorPosition = null

  # Public: Retrieves the current {EditSession}'s grammar.
  #
  # Returns a {String} indicating the {LanguageMode}'s grammar rules.
  getGrammar: -> @languageMode.grammar

  # Public: Sets the current {EditSession}'s grammar.
  #
  # grammar - A {String} indicating the {LanguageMode}'s grammar rules.
  setGrammar: (grammar) ->
    @languageMode.grammar = grammar
    @handleGrammarChange()

  reloadGrammar: ->
    @handleGrammarChange() if @languageMode.reloadGrammar()

  handleGrammarChange: ->
    @unfoldAll()
    @displayBuffer.tokenizedBuffer.resetScreenLines()
    @trigger 'grammar-changed'
    true

  getDebugSnapshot: ->
    [
      @displayBuffer.getDebugSnapshot()
      @displayBuffer.tokenizedBuffer.getDebugSnapshot()
    ].join('\n\n')

_.extend(EditSession.prototype, EventEmitter)
_.extend(EditSession.prototype, Subscriber)
