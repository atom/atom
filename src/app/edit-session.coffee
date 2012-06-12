Point = require 'point'
Buffer = require 'buffer'
Renderer = require 'renderer'
Cursor = require 'cursor'
Selection = require 'selection'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class EditSession
  @idCounter: 1

  @deserialize: (state, editor, rootView) ->
    buffer = Buffer.deserialize(state.buffer, rootView.project)
    session = new EditSession(
      editor: editor
      buffer: buffer
      autoIndent: editor.autoIndent
      softTabs: editor.softTabs
    )
    session.setScrollTop(state.scrollTop)
    session.setScrollLeft(state.scrollLeft)
    session.setCursorScreenPosition(state.cursorScreenPosition)
    session

  scrollTop: 0
  scrollLeft: 0
  renderer: null
  cursors: null
  selections: null
  autoIndent: true
  softTabs: true

  constructor: ({@editor, @buffer, @autoIndent}) ->
    @id = @constructor.idCounter++
    @tabText = @editor.tabText
    @renderer = new Renderer(@buffer, { softWrapColumn: @editor.calcSoftWrapColumn(), tabText: @editor.tabText })
    @cursors = []
    @selections = []
    @addCursorAtScreenPosition([0, 0])

    @buffer.on "change.edit-session-#{@id}", (e) =>
      for selection in @getSelections()
        selection.handleBufferChange(e)

    @renderer.on "change.edit-session-#{@id}", (e) =>
      @trigger 'screen-lines-change', e
      @moveCursors (cursor) -> cursor.refreshScreenPosition() unless e.bufferChanged

  destroy: ->
    @buffer.off ".edit-session-#{@id}"
    @renderer.off ".edit-session-#{@id}"
    @renderer.destroy()

  serialize: ->
    buffer: @buffer.serialize()
    scrollTop: @getScrollTop()
    scrollLeft: @getScrollLeft()
    cursorScreenPosition: @getCursorScreenPosition().serialize()

  isEqual: (other) ->
    return false unless other instanceof EditSession
    @buffer == other.buffer and
      @scrollTop == other.getScrollTop() and
      @scrollLeft == other.getScrollLeft() and
      @getCursorScreenPosition().isEqual(other.getCursorScreenPosition())

  getRenderer: -> @renderer

  setScrollTop: (@scrollTop) ->
  getScrollTop: -> @scrollTop

  setScrollLeft: (@scrollLeft) ->
  getScrollLeft: -> @scrollLeft

  setSoftWrapColumn: (softWrapColumn) -> @renderer.setSoftWrapColumn(softWrapColumn)
  setAutoIndent: (@autoIndent) ->
  setSoftTabs: (@softTabs) ->

  screenPositionForBufferPosition: (bufferPosition, options) ->
    @renderer.screenPositionForBufferPosition(bufferPosition, options)

  bufferPositionForScreenPosition: (screenPosition, options) ->
    @renderer.bufferPositionForScreenPosition(screenPosition, options)

  clipScreenPosition: (screenPosition, options) ->
    @renderer.clipScreenPosition(screenPosition, options)

  clipBufferPosition: (bufferPosition, options) ->
    { row, column } = Point.fromObject(bufferPosition)
    row = 0 if row < 0
    column = 0 if column < 0
    row = Math.min(@buffer.getLastRow(), row)
    column = Math.min(@buffer.lineLengthForRow(row), column)

    new Point(row, column)

  getEofBufferPosition: ->
    @buffer.getEofPosition()

  bufferRangeForBufferRow: (row) ->
    @buffer.rangeForRow(row)

  lineForBufferRow: (row) ->
    @buffer.lineForRow(row)

  scanInRange: (args...) ->
    @buffer.scanInRange(args...)

  backwardsScanInRange: (args...) ->
    @buffer.backwardsScanInRange(args...)

  getCurrentMode: ->
    @buffer.getMode()

  insertText: (text) ->
    @mutateSelectedText (selection) -> selection.insertText(text)

  insertNewline: ->
    @insertText('\n')

  insertNewlineBelow: ->
    @moveCursorToEndOfLine()
    @insertNewline()

  insertTab: ->
    if @getSelection().isEmpty()
      if @softTabs
        @insertText(@tabText)
      else
        @insertText('\t')
    else
      @activeEditSession.indentSelectedRows()

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
    if ranges = @buffer.undo()
      @setSelectedBufferRanges(ranges)

  redo: ->
    if ranges = @buffer.redo()
      @setSelectedBufferRanges(ranges)

  foldSelection: ->
    selection.fold() for selection in @getSelections()

  foldAll: ->
    @renderer.foldAll()

  toggleFold: ->
    row = @renderer.bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @renderer.toggleFoldAtBufferRow(row)

  createFold: (startRow, endRow) ->
    @renderer.createFold(startRow, endRow)

  destroyFoldsContainingBufferRow: (bufferRow) ->
    @renderer.destroyFoldsContainingBufferRow(bufferRow)

  toggleLineCommentsInRange: (range) ->
    @renderer.toggleLineCommentsInRange(range)

  mutateSelectedText: (fn) ->
    selections = @getSelections()
    @buffer.startUndoBatch(@getSelectedBufferRanges())
    fn(selection) for selection in selections
    @buffer.endUndoBatch(@getSelectedBufferRanges())

  screenLineForRow: (row) ->
    @renderer.lineForRow(row)

  stateForScreenRow: (screenRow) ->
    @renderer.stateForScreenRow(screenRow)

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

  setSelectedBufferRange: (bufferRange, options) ->
    @clearSelections()
    @getLastSelection().setBufferRange(bufferRange, options)

  setSelectedBufferRanges: (bufferRanges, options) ->
    selections = @getSelections()
    for bufferRange, i in bufferRanges
      if selections[i]
        selections[i].setBufferRange(bufferRange, options)
      else
        @addSelectionForBufferRange(bufferRange, options)
    @mergeIntersectingSelections()

  removeSelection: (selection) ->
    _.remove(@selections, selection)

  clearSelections: ->
    lastSelection = @getLastSelection()
    for selection in @getSelections() when selection != lastSelection
      selection.destroy()
    lastSelection.clear()

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
    selection.getBufferRange() for selection in @selections

  getSelectedText: ->
    @getLastSelection().getText()

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

_.extend(EditSession.prototype, EventEmitter)
