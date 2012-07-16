Point = require 'point'
Buffer = require 'buffer'
Anchor = require 'anchor'
DisplayBuffer = require 'display-buffer'
Cursor = require 'cursor'
Selection = require 'selection'
EventEmitter = require 'event-emitter'
Range = require 'range'
AnchorRange = require 'anchor-range'
_ = require 'underscore'

module.exports =
class EditSession
  @idCounter: 1

  @deserialize: (state, project) ->
    session = project.open(state.buffer)
    session.setScrollTop(state.scrollTop)
    session.setScrollLeft(state.scrollLeft)
    session.setCursorScreenPosition(state.cursorScreenPosition)
    session

  scrollTop: 0
  scrollLeft: 0
  displayBuffer: null
  anchors: null
  anchorRanges: null
  cursors: null
  selections: null
  autoIndent: true
  softTabs: true
  softWrap: false

  constructor: ({@project, @buffer, @tabText, @autoIndent, @softTabs, @softWrap}) ->
    @id = @constructor.idCounter++
    @softTabs ?= true
    @displayBuffer = new DisplayBuffer(@buffer, { @tabText })
    @tokenizedBuffer = @displayBuffer.tokenizedBuffer
    @anchors = []
    @anchorRanges = []
    @cursors = []
    @selections = []
    @addCursorAtScreenPosition([0, 0])

    @buffer.on "path-change.edit-session-#{@id}", =>
      @trigger 'buffer-path-change'

    @buffer.on "change.edit-session-#{@id}", (e) => @mergeCursors()

    @displayBuffer.on "change.edit-session-#{@id}", (e) =>
      @trigger 'screen-lines-change', e
      unless e.bufferChanged
        anchor.refreshScreenPosition() for anchor in @getAnchors()

  destroy: ->
    @buffer.off ".edit-session-#{@id}"
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

  setScrollTop: (@scrollTop) ->
  getScrollTop: -> @scrollTop

  setScrollLeft: (@scrollLeft) ->
  getScrollLeft: -> @scrollLeft

  setSoftWrapColumn: (@softWrapColumn) -> @displayBuffer.setSoftWrapColumn(@softWrapColumn)
  setAutoIndent: (@autoIndent) ->
  setSoftTabs: (@softTabs) ->

  getSoftWrap: -> @softWrap
  setSoftWrap: (@softWrap) ->

  clipBufferPosition: (bufferPosition) ->
    @buffer.clipPosition(bufferPosition)

  getFileExtension: -> @buffer.getExtension()
  getPath: -> @buffer.getPath()
  getEofBufferPosition: -> @buffer.getEofPosition()
  bufferRangeForBufferRow: (row) -> @buffer.rangeForRow(row)
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
  stateForScreenRow: (screenRow) -> @displayBuffer.stateForScreenRow(screenRow)
  screenLineCount: -> @displayBuffer.lineCount()
  maxScreenLineLength: -> @displayBuffer.maxLineLength()
  getLastScreenRow: -> @displayBuffer.getLastRow()
  bufferRowsForScreenRows: (startRow, endRow) -> @displayBuffer.bufferRowsForScreenRows(startRow, endRow)
  logScreenLines: (start, end) -> @displayBuffer.logLines(start, end)

  insertText: (text) ->
    @mutateSelectedText (selection) -> selection.insertText(text)

  insertNewline: ->
    @insertText('\n')

  insertNewlineBelow: ->
    @moveCursorToEndOfLine()
    @insertNewline()

  indent: ->
    if @getSelection().isEmpty()
      whitespaceMatch = @lineForBufferRow(@getCursorBufferPosition().row).match /^\s*$/
      if @autoIndent and whitespaceMatch
        indentation = @indentationForRow(@getCursorBufferPosition().row)
        if indentation.length > whitespaceMatch[0].length
          @getSelection().selectLine()
          @insertText(indentation)
        else
          @insertText(@tabText)
      else if @softTabs
        @insertText(@tabText)
      else
        @insertText('\t')
    else
      @indentSelectedRows()

  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

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
    @insertText($native.readFromPasteboard())

  undo: ->
    @buffer.undo(this)

  redo: ->
    @buffer.redo(this)

  foldSelection: ->
    selection.fold() for selection in @getSelections()

  foldAll: ->
    @displayBuffer.foldAll()

  toggleFold: ->
    bufferRow = @bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @toggleFoldAtBufferRow(bufferRow)

  toggleFoldAtBufferRow: (bufferRow) ->
    @displayBuffer.toggleFoldAtBufferRow(bufferRow)

  createFold: (startRow, endRow) ->
    @displayBuffer.createFold(startRow, endRow)

  destroyFoldsContainingBufferRow: (bufferRow) ->
    @displayBuffer.destroyFoldsContainingBufferRow(bufferRow)

  unfoldCurrentRow: ->
    @largestFoldStartingAtBufferRow(@getLastCursor().getBufferRow())?.destroy()

  destroyFold: (foldId) ->
    fold = @displayBuffer.foldsById[foldId]
    fold.destroy()
    @setCursorBufferPosition([fold.startRow, 0])

  isFoldedAtScreenRow: (screenRow) ->
    @lineForScreenRow(screenRow).fold?

  largestFoldStartingAtBufferRow: (bufferRow) ->
    @displayBuffer.largestFoldStartingAtBufferRow(bufferRow)

  largestFoldContainingBufferRow: (bufferRow) ->
    @displayBuffer.largestFoldContainingBufferRow(bufferRow)

  largestFoldStartingAtScreenRow: (screenRow) ->
    @displayBuffer.largestFoldStartingAtScreenRow(screenRow)

  indentationForRow: (row) ->
    @tokenizedBuffer.indentationForRow(row)

  autoIndentTextAfterBufferPosition: (text, bufferPosition) ->
    return { text } unless @autoIndent
    @tokenizedBuffer.autoIndentTextAfterBufferPosition(text, bufferPosition)

  autoOutdentBufferRow: (bufferRow) ->
    @tokenizedBuffer.autoOutdentBufferRow(bufferRow)

  toggleLineCommentsInRange: (range) ->
    @tokenizedBuffer.toggleLineCommentsInRange(range)

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

  removeAnchorRange: (anchorRange) ->
    _.remove(@anchorRanges, anchorRange)

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

  addSelectionForBufferRange: (bufferRange, options) ->
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
      unless options.preserveFolds
        for row in [bufferRange.start.row..bufferRange.end.row]
          @destroyFoldsContainingBufferRow(row)
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

  setCursorBufferPosition: (position) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(position)

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

  moveCursorUp: ->
    @moveCursors (cursor) -> cursor.moveUp()

  moveCursorDown: ->
    @moveCursors (cursor) -> cursor.moveDown()

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

  moveCursorToNextWord: ->
    @moveCursors (cursor) -> cursor.moveToNextWord()

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
