Point = require 'point'
getWordRegex = -> /(\w+)|([^\w\s]+)/g

class Motion
  constructor: (@editor) ->
  isComplete: -> true

class MoveLeft extends Motion
  execute: ->
    {column, row} = @editor.getCursorScreenPosition()
    @editor.moveCursorLeft() if column > 0

  select: ->
    position = @editor.getCursorScreenPosition()
    position.column-- if position.column > 0
    @editor.selectToBufferPosition(position)

class MoveRight extends Motion
  execute: ->
    {column, row} = @editor.getCursorScreenPosition()
    @editor.moveCursorRight()

class MoveUp extends Motion
  execute: ->
    {column, row} = @editor.getCursorScreenPosition()
    @editor.moveCursorUp() if row > 0

class MoveDown extends Motion
  execute: ->
    {column, row} = @editor.getCursorScreenPosition()
    @editor.moveCursorDown() if row < (@editor.buffer.numLines() - 1)

class MoveToPreviousWord extends Motion
  execute: ->
    @editor.getCursor().moveLeftUntilMatch /^\s*(\w+|[^A-Za-z0-9_ ]+)/

  select: ->
    @editor.getSelection().selectLeftUntilMatch /^\s*(\w+|[^A-Za-z0-9_ ]+)/

class MoveToNextWord extends Motion
  execute: ->
    @editor.setCursorScreenPosition(@nextWordPosition())

  select: ->
    @editor.selectToBufferPosition(@nextWordPosition())

  nextWordPosition: ->
    regex = getWordRegex()
    { row, column } = @editor.getCursorScreenPosition()
    rightOfCursor = @editor.buffer.lineForRow(row).substring(column)

    match = regex.exec(rightOfCursor)
    # If we're on top of part of a word, match the next one.
    match = regex.exec(rightOfCursor) if match?.index is 0

    if match
      column += match.index
    else if row + 1 == @editor.buffer.numLines()
      column = @editor.buffer.lineForRow(row).length
    else
      nextLineMatch = regex.exec(@editor.buffer.lineForRow(++row))
      column = nextLineMatch?.index or 0
    { row, column }

class MoveToNextParagraph extends Motion
  execute: ->
    @editor.setCursorScreenPosition(@nextPosition())

  select: ->
    @editor.selectToPosition(@nextPosition())

  nextPosition: ->
    regex = /[^\n]\n^$/gm
    row = null
    column = 0

    startRow = @editor.getCursorBufferRow() + 1
    for r in [startRow..@editor.buffer.lastRow()]
      if @editor.buffer.lineForRow(r).length == 0
        row = r
        break

    if not row
      row = @editor.buffer.lastRow()
      column = @editor.buffer.lastLine().length - 1

    new Point(row, column)

module.exports = { Motion, MoveLeft, MoveRight, MoveUp, MoveDown, MoveToNextWord, MoveToPreviousWord, MoveToNextParagraph }
