Cursor = require 'cursor'
_ = require 'underscore'

module.exports =
class CompositeCursor
  constructor: (@editor) ->
    @cursors = []
    @addCursor()

  getCursor: (index) ->
    index ?= @cursors.length - 1
    @cursors[index]

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
    @modifyCursors (cursor) -> cursor.setScreenPosition(screenPosition)

  setBufferPosition: (bufferPosition) ->
    @modifyCursors (cursor) -> cursor.setBufferPosition(bufferPosition)

  refreshScreenPosition: ->
    @modifyCursors (cursor) -> cursor.refreshScreenPosition()

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
