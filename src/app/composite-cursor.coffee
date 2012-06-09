CursorView = require 'cursor-view'
_ = require 'underscore'

module.exports =
class CompositeCursor
  constructor: (@editor) ->
    @cursors = []

  getCursorView: (index) ->
    index ?= @cursors.length - 1
    @cursors[index]

  getCursorViews: ->
    @cursors

  addCursorView: (cursor) ->
    cursor = new CursorView(cursor, @editor)
    @cursors.push(cursor)
    @editor.renderedLines.append(cursor)
    cursor

  viewForCursor: (cursor) ->
    for view in @getCursors()
      return view if view.cursor == cursor

  removeAllCursorViews: ->
    cursor.remove() for cursor in @getCursorViews()

  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  updateAppearance: ->
    cursor.updateAppearance() for cursor in @cursors
