getWordRegex = -> /(\w+)|([^\w\s]+)/g

class Motion
  constructor: (@editor) ->
  isComplete: -> true

class MoveLeft extends Motion
  execute: ->
    {column, row} = @editor.getCursorPosition()
    @editor.moveCursorLeft() if column > 0

  select: ->
    position = @editor.getCursorPosition()
    position.column-- if position.column > 0
    @editor.selectToPosition position

class MoveRight extends Motion
  execute: ->
    {column, row} = @editor.getCursorPosition()
    @editor.moveCursorRight()

class MoveUp extends Motion
  execute: ->
    {column, row} = @editor.getCursorPosition()
    @editor.moveCursorUp() if row > 0

class MoveDown extends Motion
  execute: ->
    {column, row} = @editor.getCursorPosition()
    @editor.moveCursorDown() if row < (@editor.buffer.numLines() - 1)

class MoveToPreviousWord extends Motion
  execute: ->
    @editor.getCursor().moveLeftUntilMatch /^\s*(\w+|[^A-Za-z0-9_ ]+)/

  select: ->
    @editor.getSelection().selectLeftUntilMatch /^\s*(\w+|[^A-Za-z0-9_ ]+)/

class MoveToNextWord extends Motion
  execute: ->
    @editor.setCursorPosition(@nextWordPosition())

  select: ->
    @editor.selectToPosition(@nextWordPosition())

  nextWordPosition: ->
    regex = getWordRegex()
    { row, column } = @editor.getCursorPosition()
    rightOfCursor = @editor.buffer.getLine(row).substring(column)

    match = regex.exec(rightOfCursor)
    # If we're on top of part of a word, match the next one.
    match = regex.exec(rightOfCursor) if match?.index is 0

    if match
      column += match.index
    else if row + 1 == @editor.buffer.numLines()
      column = @editor.buffer.getLine(row).length
    else
      nextLineMatch = regex.exec(@editor.buffer.getLine(++row))
      column = nextLineMatch?.index or 0
    { row, column }

module.exports = { Motion, MoveLeft, MoveRight, MoveUp, MoveDown, MoveToNextWord, MoveToPreviousWord }
