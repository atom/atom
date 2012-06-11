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

  removeCursorView: (cursorView) ->
    _.remove(@cursors, cursorView)

  removeAllCursorViews: ->
    cursor.remove() for cursor in @getCursorViews()

  updateAppearance: ->
    cursor.updateAppearance() for cursor in @cursors
