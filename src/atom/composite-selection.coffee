Selection = require 'selection'

module.exports =
class CompositeSeleciton
  constructor: (@editor) ->
    @selections = []

  getSelections: -> @selections

  addSelectionForCursor: (cursor) ->
    selection = new Selection({@editor, cursor})
    @selections.push(selection)
    @editor.lines.append(selection)

  insertText: (text) ->
    selection.insertText(text) for selection in @selections

  backspace: ->
    selection.backspace() for selection in @selections
