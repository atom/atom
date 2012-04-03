Selection = require 'selection'
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

  getLastSelection: ->
    _.last(@selections)

  getLastSelectionInBuffer: ->
    _.last(@getSelections().sort (a, b) ->
      aRange = a.getBufferRange()
      bRange = b.getBufferRange()
      aRange.end.compare(bRange.end))

  clearSelections: ->
    for selection in @getSelections()[1..]
      selection.cursor.remove()

    @getLastSelection().clearSelection()

  addSelectionForCursor: (cursor) ->
    selection = new Selection({@editor, cursor})
    @selections.push(selection)
    @editor.lines.append(selection)
    selection

  addSelectionForBufferRange: (bufferRange, options) ->
    cursor = @editor.compositeCursor.addCursor()
    @selectionForCursor(cursor).setBufferRange(bufferRange, options)

  removeSelectionForCursor: (cursor) ->
    selection = @selectionForCursor(cursor)
    selection.cursor = null
    selection.remove()
    _.remove(@selections, selection)

  selectionForCursor: (cursor) ->
    _.find @selections, (selection) -> selection.cursor == cursor

  setBufferRange: (bufferRange, options) ->
    @getLastSelection().setBufferRange(bufferRange, options)

  getBufferRange: (bufferRange) ->
    @getLastSelection().getBufferRange()

  getText: ->
    @getLastSelection().getText()

  moveSelectionsForward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections()

  moveSelectionsBackward: (fn) ->
    fn(selection) for selection in @getSelections()
    @mergeIntersectingSelections(reverse: true)

  insertText: (text) ->
    selection.insertText(text) for selection in @getSelections()

  backspace: ->
    selection.backspace() for selection in @getSelections()

  backspaceToBeginningOfWord: ->
    selection.backspaceToBeginningOfWord() for selection in @getSelections()

  delete: ->
    selection.delete() for selection in @getSelections()

  deleteToEndOfWord: ->
    selection.deleteToEndOfWord() for selection in @getSelections()

  selectToScreenPosition: (position) ->
    @getLastSelection().selectToScreenPosition(position)

  selectRight: ->
    @moveSelectionsForward (selection) => selection.selectRight()

  selectLeft: ->
    @moveSelectionsBackward (selection) => selection.selectLeft()

  selectUp: ->
    @moveSelectionsBackward (selection) => selection.selectUp()

  selectDown: ->
    @moveSelectionsForward (selection) => selection.selectDown()

  selectToTop: ->
    @moveSelectionsBackward (selection) => selection.selectToTop()

  selectToBottom: ->
    @moveSelectionsForward (selection) => selection.selectToBottom()

  selectToBeginningOfLine: ->
    @moveSelectionsBackward (selection) => selection.selectToBeginningOfLine()

  selectToEndOfLine: ->
    @moveSelectionsForward (selection) => selection.selectToEndOfLine()

  selectToBeginningOfWord: ->
    @moveSelectionsBackward (selection) => selection.selectToBeginningOfWord()

  selectToEndOfWord: ->
    @moveSelectionsForward (selection) => selection.selectToEndOfWord()

  cut: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.cut(maintainPasteboard)
      maintainPasteboard = true

  copy: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.copy(maintainPasteboard)
      maintainPasteboard = true

  mergeIntersectingSelections: (options) ->
    for selection in @getSelections()
      otherSelections = @getSelections()
      _.remove(otherSelections, selection)
      for otherSelection in otherSelections
        if selection.intersectsWith(otherSelection)
          selection.merge(otherSelection, options)
          @mergeIntersectingSelections(options)
          return
