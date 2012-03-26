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

  removeSelectionForCursor: (cursor) ->
    _.remove(@selections, @selectionForCursor(cursor))

  selectionForCursor: (cursor) ->
    _.find @selections, (selection) -> selection.cursor == cursor

  insertText: (text) ->
    selection.insertText(text) for selection in @selections

  backspace: ->
    for selection in @getSelections()
      selection.backspace()

  selectToScreenPosition: (position) ->
    @lastSelection().selectToScreenPosition(position)

  setBufferRange: (bufferRange) ->
    @lastSelection().setBufferRange(bufferRange)

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
