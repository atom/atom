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
    position = @editor.getCursorScreenPosition().copy()
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
    @editor.moveCursorDown() if row < (@editor.getBuffer().getLineCount() - 1)

class MoveToPreviousWord extends Motion
  execute: ->
    @editor.getCursor().moveToBeginningOfWord()

  select: ->
    @editor.getSelection().selectToBeginningOfWord()

class MoveToNextWord extends Motion
  execute: ->
    @editor.setCursorScreenPosition(@nextWordPosition())

  select: ->
    @editor.selectToBufferPosition(@nextWordPosition())

  nextWordPosition: ->
    regex = getWordRegex()
    { row, column } = @editor.getCursorScreenPosition()
    rightOfCursor = @editor.lineForBufferRow(row).substring(column)

    match = regex.exec(rightOfCursor)
    # If we're on top of part of a word, match the next one.
    match = regex.exec(rightOfCursor) if match?.index is 0

    if match
      column += match.index
    else if row + 1 == @editor.getBuffer().getLineCount()
      column = @editor.lineForBufferRow(row).length
    else
      nextLineMatch = regex.exec(@editor.lineForBufferRow(++row))
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
    for r in [startRow..@editor.getLastBufferRow()]
      if @editor.lineForBufferRow(r).length == 0
        row = r
        break

    if not row
      row = @editor.getLastBufferRow()
      column = @editor.getBuffer().getLastLine().length - 1

    new Point(row, column)

module.exports = { Motion, MoveLeft, MoveRight, MoveUp, MoveDown, MoveToNextWord, MoveToPreviousWord, MoveToNextParagraph }
