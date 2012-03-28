Selection = require 'selection'
_ = require 'underscore'

module.exports =
class CompositeSeleciton
  constructor: (@editor) ->
    @selections = []

  getSelection: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  getSelections: -> new Array(@selections...)

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

  addSelectionForBufferRange: (bufferRange, options) ->
    selections = @getSelections()
    cursor = if selections.length == 1 and selections[0].isEmpty()
      selections[0].cursor
    else
      @editor.compositeCursor.addCursor()

    @selectionForCursor(cursor).setBufferRange(bufferRange, options)

  removeSelectionForCursor: (cursor) ->
    selection = @selectionForCursor(cursor)
    selection.cursor = null
    selection.remove()
    _.remove(@selections, selection)

  selectionForCursor: (cursor) ->
    _.find @selections, (selection) -> selection.cursor == cursor

  handleBufferChange: (e) ->
    selection.handleBufferChange(e) for selection in @getSelections()

  insertText: (text) ->
    @modifySelectedText (selection) ->
      selection.insertText(text)

  backspace: ->
    @modifySelectedText (selection) -> selection.backspace()

  delete: ->
    @modifySelectedText (selection) -> selection.delete()

  selectToScreenPosition: (position) ->
    @getLastSelection().selectToScreenPosition(position)

  selectRight: ->
    selection.selectRight() for selection in @getSelections()
    @mergeIntersectingSelections()

  selectLeft: ->
    selection.selectLeft() for selection in @getSelections()
    @mergeIntersectingSelections reverse: true

  selectUp: ->
    selection.selectUp() for selection in @getSelections()
    @mergeIntersectingSelections reverse: true

  selectDown: ->
    selection.selectDown() for selection in @getSelections()
    @mergeIntersectingSelections()

  selectToTop: ->
    selection.selectToTop() for selection in @getSelections()
    @mergeIntersectingSelections reverse: true

  selectToBottom: ->
    selection.selectToBottom() for selection in @getSelections()
    @mergeIntersectingSelections()

  setBufferRange: (bufferRange, options) ->
    @getLastSelection().setBufferRange(bufferRange, options)

  getBufferRange: (bufferRange) ->
    @getLastSelection().getBufferRange()

  getText: ->
    @getLastSelection().getText()

  getLastSelection: ->
    _.last(@selections)

  mergeIntersectingSelections: (options) ->
    for selection in @getSelections()
      otherSelections = @getSelections()
      _.remove(otherSelections, selection)
      for otherSelection in otherSelections
        if selection.intersectsWith(otherSelection)
          selection.merge(otherSelection, options)
          @mergeIntersectingSelections(options)
          return

  modifySelectedText: (fn) ->
    selection.retainSelection = true for selection in @getSelections()
    for selection in @getSelections()
      selection.retainSelection = false
      fn(selection)

  cut: ->
    maintainPasteboard = false
    @modifySelectedText (selection) ->
      selection.cut(maintainPasteboard)
      maintainPasteboard = true

  copy: ->
    maintainPasteboard = false
    for selection in @getSelections()
      selection.copy(maintainPasteboard)
      maintainPasteboard = true
