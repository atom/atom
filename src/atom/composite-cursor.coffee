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

  addCursorAtBufferPosition: (bufferPosition) ->
    cursor = @addCursor()
    cursor.setBufferPosition(bufferPosition)

  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  moveCursors: (fn) ->
    fn(cursor) for cursor in @cursors
    @mergeCursors()

  setScreenPosition: (screenPosition) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(screenPosition)

  setBufferPosition: (bufferPosition) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(bufferPosition)

  refreshScreenPosition: ->
    @moveCursors (cursor) -> cursor.refreshScreenPosition()

  moveLeft: ->
    @moveCursors (cursor) -> cursor.moveLeft()

  moveRight: ->
    @moveCursors (cursor) -> cursor.moveRight()

  moveUp: ->
    @moveCursors (cursor) -> cursor.moveUp()

  moveDown: ->
    @moveCursors (cursor) -> cursor.moveDown()

  moveToNextWord: ->
    @moveCursors (cursor) -> cursor.moveToNextWord()

  moveToBeginningOfWord: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfWord()

  moveToEndOfWord: ->
    @moveCursors (cursor) -> cursor.moveToEndOfWord()

  moveToTop: ->
    @moveCursors (cursor) -> cursor.moveToTop()

  moveToBottom: ->
    @moveCursors (cursor) -> cursor.moveToBottom()

  moveToBeginningOfLine: ->
    @moveCursors (cursor) -> cursor.moveToBeginningOfLine()

  moveToEndOfLine: ->
    @moveCursors (cursor) -> cursor.moveToEndOfLine()

  moveToFirstCharacterOfLine: ->
    @moveCursors (cursor) -> cursor.moveToFirstCharacterOfLine()

  handleBufferChange: (e) ->
    @moveCursors (cursor) -> cursor.handleBufferChange(e)

  mergeCursors: ->
    positions = []
    for cursor in new Array(@cursors...)
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.remove()
      else
        positions.push(position)
