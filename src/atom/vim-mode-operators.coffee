_ = require 'underscore'

getWordRegex = -> /(\w+)|([^\w\s]+)/g

module.exports =
  NumericPrefix: class
    count: null
    operatorToRepeat: null
    complete: null

    constructor: (@count) ->
      @complete = false

    compose: (@operatorToRepeat) ->
      @complete = true

    isComplete: -> @complete

    addDigit: (digit) ->
      @count = @count * 10 + digit

    execute: (editor) ->
      _.times @count, => @operatorToRepeat.execute(editor)

    select: (editor) ->
      _.times @count, => @operatorToRepeat.select(editor)

  Delete: class
    complete: null
    motion: null

    execute: (editor) ->
      if @motion
        @motion.select(editor)
        editor.delete()
      else
        editor.deleteLine()

    compose: (motion) ->
      @motion = motion
      @complete = true

    isComplete: -> @complete

  DeleteChar: class
    execute: (editor) ->
      editor.deleteChar()

    isComplete: -> true

  MoveLeft: class
    execute: (editor) ->
      {column, row} = editor.getCursor()
      editor.moveLeft() if column > 0

    isComplete: -> true

  MoveUp: class
    execute: (editor) ->
      {column, row} = editor.getCursor()
      editor.moveUp() if row > 0

    isComplete: -> true

  MoveToNextWord: class
    isComplete: -> true

    execute: (editor) ->
      editor.setCursor(@nextWordPosition(editor))

    select: (editor) ->
      editor.selectToPosition(@nextWordPosition(editor))

    nextWordPosition: (editor) ->
      regex = getWordRegex()
      { row, column } = editor.getCursor()
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


