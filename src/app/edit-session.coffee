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
fsUtils = require 'fs-utils'

module.exports =
class EditSession
  registerDeserializer(this)

  @version: 1

  @deserialize: (state) ->
    session = project.buildEditSessionForBuffer(Buffer.deserialize(state.buffer))
    if !session?
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
      @project.setPath(fsUtils.directory(@getPath())) unless @project.getPath()?
      @trigger "title-changed"
      @trigger "path-changed"
    @subscribe @buffer, "contents-conflicted", => @trigger "contents-conflicted"
    @subscribe @buffer, "markers-updated", => @mergeCursors()
    @subscribe @buffer, "modified-status-changed", => @trigger "modified-status-changed"

    @preserveCursorPositionOnBufferReload()

    @subscribe @displayBuffer, "changed", (e) =>
      @trigger 'screen-lines-changed', e

    @languageMode.on 'grammar-changed', => @handleGrammarChange()

  getViewClass: ->
    require 'editor'

  getTitle: ->
    if path = @getPath()
      fsUtils.base(path)
    else
      'untitled'

  getLongTitle: ->
    if path = @getPath()
      fileName = fsUtils.base(path)
      directory = fsUtils.base(fsUtils.directory(path))
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
    @languageMode.destroy()
    @project?.removeEditSession(this)
    @trigger 'destroyed'
    @off()

  serialize: ->
    deserializer: 'EditSession'
    version: @constructor.version
    buffer: @buffer.serialize()
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
  getFileExtension: -> @buffer.getExtension()
  getPath: -> @buffer.getPath()
  getUri: -> @getPath()
  isBufferRowBlank: (bufferRow) -> @buffer.isRowBlank(bufferRow)
  nextNonBlankBufferRow: (bufferRow) -> @buffer.nextNonBlankRow(bufferRow)
  getEofBufferPosition: -> @buffer.getEofPosition()
  getLastBufferRow: -> @buffer.getLastRow()
  bufferRangeForBufferRow: (row, options) -> @buffer.rangeForRow(row, options)
  lineForBufferRow: (row) -> @buffer.lineForRow(row)
  lineLengthForBufferRow: (row) -> @buffer.lineLengthForRow(row)
  scanInBufferRange: (args...) -> @buffer.scanInRange(args...)
  backwardsScanInBufferRange: (args...) -> @buffer.backwardsScanInRange(args...)
  isModified: -> @buffer.isModified()
  hasEditors: -> @buffer.hasEditors()

  screenPositionForBufferPosition: (bufferPosition, options) -> @displayBuffer.screenPositionForBufferPosition(bufferPosition, options)
  bufferPositionForScreenPosition: (screenPosition, options) -> @displayBuffer.bufferPositionForScreenPosition(screenPosition, options)
  screenRangeForBufferRange: (range) -> @displayBuffer.screenRangeForBufferRange(range)
  bufferRangeForScreenRange: (range) -> @displayBuffer.bufferRangeForScreenRange(range)
  clipScreenPosition: (screenPosition, options) -> @displayBuffer.clipScreenPosition(screenPosition, options)
  lineForScreenRow: (row) -> @displayBuffer.lineForRow(row)
  linesForScreenRows: (start, end) -> @displayBuffer.linesForRows(start, end)
  screenLineCount: -> @displayBuffer.lineCount()
  maxScreenLineLength: -> @displayBuffer.maxLineLength()
  getLastScreenRow: -> @displayBuffer.getLastRow()
  bufferRowsForScreenRows: (startRow, endRow) -> @displayBuffer.bufferRowsForScreenRows(startRow, endRow)
  scopesForBufferPosition: (bufferPosition) -> @displayBuffer.scopesForBufferPosition(bufferPosition)
  getCursorScopes: -> @getCursor().getScopes()
  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)

  shouldAutoIndent: ->
    config.get("editor.autoIndent")

  shouldAutoIndentPastedText: ->
    config.get("editor.autoIndentOnPaste")

  insertText: (text, options={}) ->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.insertText(text, options)

  insertNewline: ->
    @insertText('\n')

  insertNewlineBelow: ->
    @transact =>
      @moveCursorToEndOfLine()
      @insertNewline()

  insertNewlineAbove: ->
    @transact =>
      onFirstLine = @getCursorBufferPosition().row is 0
      @moveCursorToBeginningOfLine()
      @moveCursorLeft()
      @insertNewline()
      @moveCursorUp() if onFirstLine

  indent: (options={})->
    options.autoIndent ?= @shouldAutoIndent()
    @mutateSelectedText (selection) -> selection.indent(options)

  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

  backspaceToBeginningOfLine: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfLine()

  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  deleteLine: ->
    @mutateSelectedText (selection) -> selection.deleteLine()

  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  toggleLineCommentsInSelection: ->
    @mutateSelectedText (selection) -> selection.toggleLineComments()

  autoIndentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.autoIndentSelectedRows()

  normalizeTabsInBufferRange: (bufferRange) ->
    return unless @softTabs
    @scanInBufferRange /\t/, bufferRange, ({replace}) => replace(@getTabText())

  cutToEndOfLine: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfLine(maintainPasteboard)
      maintainPasteboard = true

  cutSelectedText: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cut(maintainPasteboard)
      maintainPasteboard = true

  copySelectedText: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.copy(maintainPasteboard)
      maintainPasteboard = true

  pasteText: (options={}) ->
    options.normalizeIndent ?= true
    options.autoIndent ?= @shouldAutoIndentPastedText()

    [text, metadata] = pasteboard.read()
    _.extend(options, metadata) if metadata

    @insertText(text, options)

  undo: ->
    @buffer.undo(this)

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

  foldAll: ->
    @displayBuffer.foldAll()

  unfoldAll: ->
    @displayBuffer.unfoldAll()

  foldCurrentRow: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @foldBufferRow(bufferRow)

  foldBufferRow: (bufferRow) ->
    @displayBuffer.foldBufferRow(bufferRow)

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

  isFoldedAtCursorRow: ->
    @isFoldedAtScreenRow(@getCursorScreenRow())

  isFoldedAtBufferRow: (bufferRow) ->
    screenRow = @screenPositionForBufferPosition([bufferRow]).row
    @isFoldedAtScreenRow(screenRow)

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

  hasMultipleCursors: ->
    @getCursors().length > 1

  getCursors: -> new Array(@cursors...)

  getCursor: ->
    _.last(@cursors)

  addCursorAtScreenPosition: (screenPosition) ->
    marker = @markScreenPosition(screenPosition, invalidationStrategy: 'never')
    @addSelection(marker).cursor

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

  removeSelection: (selection) ->
    _.remove(@selections, selection)

  clearSelections: ->
    lastSelection = @getLastSelection()
    for selection in @getSelections() when selection != lastSelection
      selection.destroy()
    lastSelection.clear()

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

  setCursorScreenPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position, options)

  getCursorScreenPosition: ->
    @getCursor().getScreenPosition()

  getCursorScreenRow: ->
    @getCursor().getScreenRow()

  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  getCursorBufferPosition: ->
    @getCursor().getBufferPosition()

  getSelectedScreenRange: ->
    @getLastSelection().getScreenRange()

  getSelectedBufferRange: ->
    @getLastSelection().getBufferRange()

  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelectionsOrderedByBufferPosition()

  getSelectedText: ->
    @getLastSelection().getText()

  getTextInBufferRange: (range) ->
    @buffer.getTextInRange(range)

  getCurrentParagraphBufferRange: ->
    @getCursor().getCurrentParagraphBufferRange()

  getWordUnderCursor: (options) ->
    @getTextInBufferRange(@getCursor().getCurrentWordBufferRange(options))

  moveCursorUp: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveUp(lineCount)

  moveCursorDown: (lineCount) ->
    @moveCursors (cursor) -> cursor.moveDown(lineCount)

  moveCursorLeft: ->
    @moveCursors (cursor) -> cursor.moveLeft()

  moveCursorRight: ->
    @moveCursors (cursor) -> cursor.moveRight()

  moveCursorToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  moveCursorToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  moveCursorToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  moveCursorToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  moveCursorToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  moveCursorToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  moveCursorToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  moveCursors: (fn) ->
    fn(cursor) for cursor in @getCursors()
    @mergeCursors()

  selectToScreenPosition: (position) ->
    lastSelection = @getLastSelection()
    lastSelection.selectToScreenPosition(position)
    @mergeIntersectingSelections(reverse: lastSelection.isReversed())

  selectRight: ->
    @expandSelectionsForward (selection) => selection.selectRight()

  selectLeft: ->
    @expandSelectionsBackward (selection) => selection.selectLeft()

  selectUp: ->
    @expandSelectionsBackward (selection) => selection.selectUp()

  selectDown: ->
    @expandSelectionsForward (selection) => selection.selectDown()

  selectToTop: ->
    @expandSelectionsBackward (selection) => selection.selectToTop()

  selectAll: ->
    @expandSelectionsForward (selection) => selection.selectAll()

  selectToBottom: ->
    @expandSelectionsForward (selection) => selection.selectToBottom()

  selectToBeginningOfLine: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfLine()

  selectToEndOfLine: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfLine()

  selectLine: ->
    @expandSelectionsForward (selection) => selection.selectLine()

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

  upperCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toUpperCase()

  lowerCase: ->
    @replaceSelectedText selectWordIfEmpty:true, (text) => text.toLowerCase()

  expandLastSelectionOverLine: ->
    @getLastSelection().expandOverLine()

  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfWord()

  selectToEndOfWord: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfWord()

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

  getGrammar: -> @languageMode.grammar

  setGrammar: (grammar) ->
    @languageMode.setGrammar(grammar)

  reloadGrammar: ->
    @languageMode.reloadGrammar()

  handleGrammarChange: ->
    @unfoldAll()
    @trigger 'grammar-changed'

  getDebugSnapshot: ->
    [
      @displayBuffer.getDebugSnapshot()
      @displayBuffer.tokenizedBuffer.getDebugSnapshot()
    ].join('\n\n')

_.extend(EditSession.prototype, EventEmitter)
_.extend(EditSession.prototype, Subscriber)
