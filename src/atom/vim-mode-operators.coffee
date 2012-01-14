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

  Delete: class
    complete: null

    execute: (editor) ->
      editor.deleteLine()

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
    execute: (editor) ->
      regex = getWordRegex()
      { row, column } = editor.getCursor()
      rightOfCursor = editor.getLineText().substring(column)

      match = regex.exec(rightOfCursor)
      # If we're on top of part of a word, match the next one.
      match = regex.exec(rightOfCursor) if match?.index is 0
      column += match.index

      editor.setCursor { row, column }

    isComplete: -> true

