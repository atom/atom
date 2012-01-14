getWordRegex = -> /(\w+)|([^\w\s]+)/g

class Motion
  isComplete: -> true

class MoveLeft extends Motion
  execute: (editor) ->
    {column, row} = editor.getPosition()
    editor.moveLeft() if column > 0

class MoveUp extends Motion
  execute: (editor) ->
    {column, row} = editor.getPosition()
    editor.moveUp() if row > 0

class MoveToNextWord extends Motion
  execute: (editor) ->
    editor.setPosition(@nextWordPosition(editor))

  select: (editor) ->
    editor.selectToPosition(@nextWordPosition(editor))

  nextWordPosition: (editor) ->
    regex = getWordRegex()
    { row, column } = editor.getPosition()
    rightOfCursor = editor.getLineText(row).substring(column)

    match = regex.exec(rightOfCursor)
    # If we're on top of part of a word, match the next one.
    match = regex.exec(rightOfCursor) if match?.index is 0

    if match
      column += match.index
    else
      nextLineMatch = regex.exec(editor.getLineText(++row))
      column = nextLineMatch?.index or 0
    { row, column }

class SelectLine extends Motion
  select: (editor) ->
    editor.selectLine()

module.exports = { MoveLeft, MoveUp, MoveToNextWord, SelectLine }

