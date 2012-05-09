Cursor = require 'cursor'
_ = require 'underscore'

module.exports =
class CompositeCursor
  constructor: (@editor) ->
    @cursors = []
    @addCursor()

  handleBufferChange: (e) ->
    @moveCursors (cursor) -> cursor.handleBufferChange(e)

  getCursor: (index) ->
    index ?= @cursors.length - 1
    @cursors[index]

  getCursors: ->
    @cursors

  addCursor: (screenPosition=null) ->
    cursor = new Cursor({@editor, screenPosition})
    @cursors.push(cursor)
    @editor.lines.append(cursor)
    cursor

  addCursorAtScreenPosition: (screenPosition) ->
    cursor = @addCursor(screenPosition)

  addCursorAtBufferPosition: (bufferPosition) ->
    screenPosition = @editor.screenPositionForBufferPosition(bufferPosition)
    cursor = @addCursor(screenPosition)

  removeCursor: (cursor) ->
    _.remove(@cursors, cursor)

  updateAppearance: ->
    cursor.updateAppearance() for cursor in @cursors

  moveCursors: (fn) ->
    fn(cursor) for cursor in @cursors
    @mergeCursors()

  setScreenPosition: (screenPosition) ->
    @moveCursors (cursor) -> cursor.setScreenPosition(screenPosition)

  setBufferPosition: (bufferPosition) ->
    @moveCursors (cursor) -> cursor.setBufferPosition(bufferPosition)

  updateBufferPosition: ->
    @moveCursors (cursor) -> cursor.setBufferPosition(cursor.getBufferPosition())

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

  mergeCursors: ->
    positions = []
    for cursor in new Array(@cursors...)
      position = cursor.getBufferPosition().toString()
      if position in positions
        cursor.remove()
      else
        positions.push(position)
