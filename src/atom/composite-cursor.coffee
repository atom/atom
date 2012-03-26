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

  modifyCursors: (fn) ->
    fn(cursor) for cursor in @cursors
    @mergeCursors()

  moveLeft: ->
    @modifyCursors (cursor) -> cursor.moveLeft()

  moveRight: ->
    @modifyCursors (cursor) -> cursor.moveRight()

  moveUp: ->
    @modifyCursors (cursor) -> cursor.moveUp()

  moveDown: ->
    @modifyCursors (cursor) -> cursor.moveDown()

  handleBufferChange: (e) ->
    @modifyCursors (cursor) -> cursor.handleBufferChange(e)

  mergeCursors: ->
    positions = []
    for cursor in new Array(@cursors...)
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.remove()
      else
        positions.push(position)
