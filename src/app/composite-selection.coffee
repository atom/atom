SelectionView = require 'selection-view'
_ = require 'underscore'

module.exports =
class CompositeSeleciton
  constructor: (@editor) ->
    @selections = []

  getSelectionView: (index) ->
    index ?= @selections.length - 1
    @selections[index]

  addSelectionView: (selection) ->
    selection = new SelectionView({@editor, selection})
    @selections.push(selection)
    @editor.renderedLines.append(selection)
    selection

  selectionViewForCursor: (cursor) ->
    for view in @selections
      return view if view.selection.cursor == cursor

  removeSelectionView: (selectionView) ->
    _.remove(@selections, selectionView)
