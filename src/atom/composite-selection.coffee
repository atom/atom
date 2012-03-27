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

  addSelectionForCursor: (cursor) ->
    selection = new Selection({@editor, cursor})
    @selections.push(selection)
    @editor.lines.append(selection)

  addSelectionForBufferRange: (bufferRange, options) ->
    cursor = @editor.compositeCursor.addCursor()
    @selectionForCursor(cursor).setBufferRange(bufferRange, options)

  removeSelectionForCursor: (cursor) ->
    _.remove(@selections, @selectionForCursor(cursor))

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
    @lastSelection().selectToScreenPosition(position)

  selectRight: ->
    selection.selectRight() for selection in @getSelections()
    @mergeIntersectingSelections()

  selectLeft: ->
    selection.selectLeft() for selection in @getSelections()
    @mergeIntersectingSelections()

  selectUp: ->
    selection.selectUp() for selection in @getSelections()
    @mergeIntersectingSelections()

  selectDown: ->
    selection.selectDown() for selection in @getSelections()
    @mergeIntersectingSelections()

  setBufferRange: (bufferRange, options) ->
    @lastSelection().setBufferRange(bufferRange, options)

  getBufferRange: (bufferRange) ->
    @lastSelection().getBufferRange()

  getText: ->
    @lastSelection().getText()

  lastSelection: ->
    _.last(@selections)

  mergeIntersectingSelections: ->
    for selection in @getSelections()
      otherSelections = @getSelections()
      _.remove(otherSelections, selection)
      for otherSelection in otherSelections
        if selection.intersectsWith(otherSelection)
          selection.merge(otherSelection)
          @mergeIntersectingSelections()
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
