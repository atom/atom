Point = require 'point'
Buffer = require 'buffer'
Anchor = require 'anchor'
LanguageMode = require 'language-mode'
DisplayBuffer = require 'display-buffer'
Cursor = require 'cursor'
Selection = require 'selection'
EventEmitter = require 'event-emitter'
Range = require 'range'
AnchorRange = require 'anchor-range'
_ = require 'underscore'
fs = require 'fs'

module.exports =
class EditSession
  @idCounter: 1

  @deserialize: (state, project) ->
    if fs.exists(state.buffer)
      session = project.buildEditSessionForPath(state.buffer)
    else
      console.warn "Could not build edit session for path '#{state.buffer}' because that file no longer exists"
      session = project.buildEditSessionForPath(null)
    session.setScrollTop(state.scrollTop)
    session.setScrollLeft(state.scrollLeft)
    session.setCursorScreenPosition(state.cursorScreenPosition)
    session

  scrollTop: 0
  scrollLeft: 0
  languageMode: null
  displayBuffer: null
  anchors: null
  anchorRanges: null
  cursors: null
  selections: null
  autoIndent: false # TODO: re-enabled auto-indent after fixing the rest of tokenization
  softTabs: true
  softWrap: false

  constructor: ({@project, @buffer, tabLength, @autoIndent, softTabs, @softWrap }) ->
    @id = @constructor.idCounter++
    @softTabs = @buffer.usesSoftTabs() ? softTabs ? true
    @languageMode = new LanguageMode(this, @buffer.getExtension())
    @displayBuffer = new DisplayBuffer(@buffer, { @languageMode, tabLength })
    @anchors = []
    @anchorRanges = []
    @cursors = []
    @selections = []
    @addCursorAtScreenPosition([0, 0])

    @buffer.retain()
    @buffer.on "path-change.edit-session-#{@id}", =>
      @trigger "buffer-path-change"

    @buffer.on "contents-conflicted.edit-session-#{@id}", =>
      @trigger "contents-conflicted"

    @buffer.on "update-anchors-after-change.edit-session-#{@id}", =>
      @mergeCursors()

    @displayBuffer.on "change.edit-session-#{@id}", (e) =>
      @refreshAnchorScreenPositions() unless e.bufferDelta
      @trigger 'screen-lines-change', e

  destroy: ->
    throw new Error("Edit session already destroyed") if @destroyed
    @destroyed = true

    @buffer.off ".edit-session-#{@id}"
    @buffer.release()
    @displayBuffer.off ".edit-session-#{@id}"
    @displayBuffer.destroy()
    @project.removeEditSession(this)
    anchor.destroy() for anchor in @getAnchors()
    anchorRange.destroy() for anchorRange in @getAnchorRanges()

  serialize: ->
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
  setAutoIndent: (@autoIndent) ->
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
      _.multiplyString("\t", number)

  save: -> @buffer.save()
  saveAs: (path) -> @buffer.saveAs(path)
  getFileExtension: -> @buffer.getExtension()
  getPath: -> @buffer.getPath()
  isBufferRowBlank: (bufferRow) -> @buffer.isRowBlank(bufferRow)
  nextNonBlankBufferRow: (bufferRow) -> @buffer.nextNonBlankRow(bufferRow)
  getEofBufferPosition: -> @buffer.getEofPosition()
  getLastBufferRow: -> @buffer.getLastRow()
  bufferRangeForBufferRow: (row, options) -> @buffer.rangeForRow(row, options)
  lineForBufferRow: (row) -> @buffer.lineForRow(row)
  scanInRange: (args...) -> @buffer.scanInRange(args...)
  backwardsScanInRange: (args...) -> @buffer.backwardsScanInRange(args...)

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
  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)

  insertText: (text, options) ->
    @mutateSelectedText (selection) -> selection.insertText(text, options)

  insertNewline: ->
    @insertText('\n', autoIndent: true)

  insertNewlineBelow: ->
    @moveCursorToEndOfLine()
    @insertNewline()

  indent: ->
    @mutateSelectedText (selection) -> selection.indent()

  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

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

  pasteText: ->
    [text, metadata] = pasteboard.read()
    @insertText(text, _.extend(metadata ? {}, normalizeIndent: true))

  undo: ->
    @buffer.undo(this)

  redo: ->
    @buffer.redo(this)

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

  mutateSelectedText: (fn) ->
    @transact => fn(selection) for selection in @getSelections()

  transact: (fn) ->
    @buffer.transact =>
      oldSelectedRanges = @getSelectedBufferRanges()
      @pushOperation
        undo: (editSession) ->
          editSession?.setSelectedBufferRanges(oldSelectedRanges)

      fn()
      newSelectedRanges = @getSelectedBufferRanges()
      @pushOperation
        redo: (editSession) ->
          editSession?.setSelectedBufferRanges(newSelectedRanges)

  pushOperation: (operation) ->
    @buffer.pushOperation(operation, this)

  getAnchors: ->
    new Array(@anchors...)

  getAnchorRanges: ->
    new Array(@anchorRanges...)

  addAnchor: (options={}) ->
    anchor = @buffer.addAnchor(_.extend({editSession: this}, options))
    @anchors.push(anchor)
    anchor

  addAnchorAtBufferPosition: (bufferPosition, options) ->
    anchor = @addAnchor(options)
    anchor.setBufferPosition(bufferPosition)
    anchor

  addAnchorRange: (range) ->
    anchorRange = @buffer.addAnchorRange(range, this)
    @anchorRanges.push(anchorRange)
    anchorRange

  removeAnchor: (anchor) ->
    _.remove(@anchors, anchor)

  refreshAnchorScreenPositions: ->
    anchor.refreshScreenPosition() for anchor in @getAnchors()

  removeAnchorRange: (anchorRange) ->
    _.remove(@anchorRanges, anchorRange)

  anchorRangesForBufferPosition: (bufferPosition) ->
    _.intersect(@anchorRanges, @buffer.anchorRangesForPosition(bufferPosition))

  hasMultipleCursors: ->
    @getCursors().length > 1

  getCursors: -> new Array(@cursors...)

  getCursor: (index=0) ->
    @cursors[index]

  getLastCursor: ->
    _.last(@cursors)

  addCursorAtScreenPosition: (screenPosition) ->
    @addCursor(new Cursor(editSession: this, screenPosition: screenPosition))

  addCursorAtBufferPosition: (bufferPosition) ->
    @addCursor(new Cursor(editSession: this, bufferPosition: bufferPosition))

  addCursor: (cursor=new Cursor(editSession: this, screenPosition: [0,0])) ->
    @cursors.push(cursor)
    @trigger 'add-cursor', cursor
    @addSelectionForCursor(cursor)
    cursor

  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  addSelectionForCursor: (cursor) ->
    selection = new Selection(editSession: this, cursor: cursor)
    @selections.push(selection)
    @trigger 'add-selection', selection
    selection

  addSelectionForBufferRange: (bufferRange, options={}) ->
    bufferRange = Range.fromObject(bufferRange)
    @destroyFoldsIntersectingBufferRange(bufferRange) unless options.preserveFolds
    @addCursor().selection.setBufferRange(bufferRange, options)
    @mergeIntersectingSelections()

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

  setCursorScreenPosition: (position) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(position)

  getCursorScreenPosition: ->
    @getLastCursor().getScreenPosition()

  getCursorScreenRow: ->
    @getLastCursor().getScreenRow()

  setCursorBufferPosition: (position, options) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position, options)

  getCursorBufferPosition: ->
    @getLastCursor().getBufferPosition()

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

  mergeCursors: ->
    positions = []
    for cursor in new Array(@getCursors()...)
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

_.extend(EditSession.prototype, EventEmitter)
