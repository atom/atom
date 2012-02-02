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
    currentLineLength = @editor.buffer.getLine(row).length
    @editor.moveCursorRight() if column < currentLineLength

class MoveUp extends Motion
  execute: ->
    {column, row} = @editor.getCursorPosition()
    @editor.moveCursorUp() if row > 0

class MoveDown extends Motion
  execute: ->
    {column, row} = @editor.getCursorPosition()
    @editor.moveCursorDown() if row < (@editor.buffer.numLines() - 1)

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
    else
      nextLineMatch = regex.exec(@editor.getLineText(++row))
      column = nextLineMatch?.index or 0
    { row, column }

class SelectLines extends Motion
  count: null

  constructor: (@editor) ->
    @count = 1

  setCount: (@count) ->

  select: ->
    @editor.setCursorPosition(column: 0, row: @editor.getCursorRow())
    @editor.selectToPosition(column: 0, row: @editor.getCursorRow() + @count)

module.exports = { MoveLeft, MoveRight, MoveUp, MoveDown, MoveToNextWord, SelectLines }
