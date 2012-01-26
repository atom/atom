Template = require 'template'
Cursor = require 'cursor'

module.exports =
class Selection extends Template
  content: ->
    @div()

  viewProperties:
    initialize: (editor) ->
      @editor = editor
      @cursor = Cursor.build(editor).appendTo(this)

    bufferChanged: (e) ->
      @cursor.setPosition(e.postRange.end)

    updateScreenPosition: ->
      @cursor.updateScreenPosition()

    setCursorPosition: (point) ->
      @cursor.setPosition(point)

    getCursorPosition: ->
      @cursor.getPosition()

    setCursorRow: (row) ->
      @cursor.setRow(row)

    getCursorRow: ->
      @cursor.getRow()

    setCursorColumn: (column) ->
      @cursor.setColumn(column)

    getCursorColumn: ->
      @cursor.getColumn()

    moveCursorUp: ->
      @cursor.moveUp()

    moveCursorDown: ->
      @cursor.moveDown()

    moveCursorLeft: ->
      @cursor.moveLeft()

    moveCursorRight: ->
      @cursor.moveRight()

    moveCursorToLineEnd: ->
      @cursor.moveToLineEnd()

    moveCursorToLineStart: ->
      @cursor.moveToLineStart()

