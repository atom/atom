Selection = require 'selection'
_ = require 'underscore'

module.exports =
class CompositeSeleciton
  constructor: (@editor) ->
    @selections = []

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
    _.last(@selections).selectToScreenPosition(position)