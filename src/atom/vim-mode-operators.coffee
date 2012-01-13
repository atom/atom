_ = require 'underscore'

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

    execute: (editor) ->
      _.times @count, => @operatorToRepeat.execute(editor)

  DeleteChar: class
    execute: (editor) ->
      editor.deleteChar()

    isComplete: -> true

  MoveLeft: class
    execute: (editor) ->
      {column, row} = editor.getCursor()
      editor.moveLeft() if column > 0

    isComplete: -> true
