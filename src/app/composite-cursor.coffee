CursorView = require 'cursor-view'
_ = require 'underscore'

module.exports =
class CompositeCursor
  constructor: (@editor) ->
    @cursors = []

  handleBufferChange: (e) ->
    @moveCursors (cursor) -> cursor.handleBufferChange(e)

  getCursor: (index) ->
    index ?= @cursors.length - 1
    @cursors[index]

  getCursors: ->
    @cursors

  addCursorView: (cursor) ->
    cursor = new CursorView(cursor, @editor)
    @cursors.push(cursor)
    @editor.renderedLines.append(cursor)
    cursor

  viewForCursor: (cursor) ->
    for view in @getCursors()
      return view if view.cursor == cursor

  removeAllCursors: ->
    cursor.remove() for cursor in @getCursors()

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
