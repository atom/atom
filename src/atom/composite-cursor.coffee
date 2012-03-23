Cursor = require 'cursor'

module.exports =
class CompositeCursor
  constructor: (@editor) ->
    @cursors = []
    @addCursor()

  getCursors: ->
    @cursors

  addCursor: ->
    cursor = new Cursor(@editor)
    @cursors.push(cursor)
    @editor.lines.append(cursor)
    @editor.addSelectionForCursor(cursor)
    cursor

  addCursorAtScreenPosition: (screenPosition) ->
    cursor = @addCursor()
    cursor.setScreenPosition(screenPosition)

  setScreenPosition: (screenPosition) ->
    cursor.setScreenPosition(screenPosition) for cursor in @cursors

  getScreenPosition: ->
    @cursors[0].getScreenPosition()

  handleBufferChange: (e) ->
    cursor.handleBufferChange(e) for cursor in @cursors
