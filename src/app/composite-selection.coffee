SelectionView = require 'selection-view'
_ = require 'underscore'

module.exports =
class CompositeSeleciton
  constructor: (@editor) ->
    @selections = []

  handleBufferChange: (e) ->
    selection.handleBufferChange(e) for selection in @getSelections()

  getSelection: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  getSelections: ->
    new Array(@selections...)

  getSelectedBufferRanges: ->
    selection.getBufferRange() for selection in @getSelections()

  getLastSelection: ->
    _.last(@selections)

  getSelectionsOrderedByBufferPosition: ->
    @getSelections().sort (a, b) ->
      aRange = a.getBufferRange()
      bRange = b.getBufferRange()
      aRange.end.compare(bRange.end)

  getLastSelectionInBuffer: ->
    _.last(@getSelectionsOrderedByBufferPosition())

  clearSelections: ->
    for selection in @getSelections()[1..]
      selection.cursor.destroy()

    @getLastSelection().clearSelection()

  addSelectionView: (selection) ->
    selection = new SelectionView({@editor, selection})
    @selections.push(selection)
    @editor.renderedLines.append(selection)
    selection

  selectionViewForCursor: (cursor) ->
    for view in @selections
      return view if view.selection.cursor == cursor

  addSelectionForBufferRange: (bufferRange, options) ->
    cursor = @editor.activeEditSession.addCursor()
    @selectionForCursor(cursor).setBufferRange(bufferRange, options)

  removeSelectionView: (selectionView) ->
    _.remove(@selections, selectionView)

  selectionForCursor: (cursor) ->
    _.find @selections, (selection) -> selection.cursor == cursor

  setBufferRange: (bufferRange, options) ->
    @getLastSelection().setBufferRange(bufferRange, options)

  setBufferRanges: (bufferRanges) ->
    selections = @getSelections()
    for bufferRange, i in bufferRanges
      if selections[i]
        selections[i].setBufferRange(bufferRange)
      else
        @addSelectionForBufferRange(bufferRange)
    @mergeIntersectingSelections()

  getBufferRange: (bufferRange) ->
    @getLastSelection().getBufferRange()

  getText: ->
    @getLastSelection().getText()

  intersectsBufferRange: (bufferRange) ->
    _.any @getSelections(), (selection) ->
      selection.intersectsBufferRange(bufferRange)

  expandSelectionsForward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections()

  expandSelectionsBackward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections(reverse: true)

  mutateSelectedText: (fn) ->
    selections = @getSelections()
    @editor.buffer.startUndoBatch(@getSelectedBufferRanges())
    fn(selection) for selection in selections
    @editor.buffer.endUndoBatch(@getSelectedBufferRanges())

  insertText: (text) ->
    @mutateSelectedText (selection) -> selection.insertText(text)

  outdentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.outdentSelectedRows()

  indentSelectedRows: ->
    @mutateSelectedText (selection) -> selection.indentSelectedRows()

  backspace: ->
    @mutateSelectedText (selection) -> selection.backspace()

  backspaceToBeginningOfWord: ->
    @mutateSelectedText (selection) -> selection.backspaceToBeginningOfWord()

  delete: ->
    @mutateSelectedText (selection) -> selection.delete()

  deleteToEndOfWord: ->
    @mutateSelectedText (selection) -> selection.deleteToEndOfWord()

  toggleLineComments: ->
    @mutateSelectedText (selection) -> selection.toggleLineComments()

  selectToScreenPosition: (position) ->
    @getLastSelection().selectToScreenPosition(position)

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

  selectToBeginningOfWord: ->
    @expandSelectionsBackward (selection) => selection.selectToBeginningOfWord()

  selectToEndOfWord: ->
    @expandSelectionsForward (selection) => selection.selectToEndOfWord()

  cutToEndOfLine: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cutToEndOfLine(maintainPasteboard)
      maintainPasteboard = true

  cut: ->
    maintainPasteboard = false
    @mutateSelectedText (selection) ->
      selection.cut(maintainPasteboard)
      maintainPasteboard = true

  copy: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.copy(maintainPasteboard)
      maintainPasteboard = true

  mergeIntersectingSelections: (options) ->
    @editor.activeEditSession.mergeIntersectingSelections(options)
