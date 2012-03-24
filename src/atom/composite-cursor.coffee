Cursor = require 'cursor'
_ = require 'underscore'

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

  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  setScreenPosition: (screenPosition) ->
    cursor.setScreenPosition(screenPosition) for cursor in @cursors

  getScreenPosition: ->
    @cursors[0].getScreenPosition()

  moveLeft: ->
    cursor.moveLeft() for cursor in @cursors

  moveRight: ->
    cursor.moveRight() for cursor in @cursors

  moveUp: ->
    cursor.moveUp() for cursor in @cursors

  moveDown: ->
    cursor.moveDown() for cursor in @cursors

  handleBufferChange: (e) ->
    cursor.handleBufferChange(e) for cursor in @cursors
    @mergeCursors()

  mergeCursors: ->
    positions = []
    for cursor in new Array(@cursors...)
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.remove()
      else
        positions.push(position)
