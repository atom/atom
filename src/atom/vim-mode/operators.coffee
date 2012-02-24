_ = require 'underscore'

class OperatorError
  constructor: (@message) ->
    @name = "Operator Error"

class NumericPrefix
  count: null
  complete: null
  operatorToRepeat: null

  constructor: (@count) ->
    @complete = false

  isComplete: -> @complete

  compose: (@operatorToRepeat) ->
    @complete = true
    if @operatorToRepeat.setCount?
      @operatorToRepeat.setCount @count
      @count = 1

  addDigit: (digit) ->
    @count = @count * 10 + digit

  execute: ->
    _.times @count, => @operatorToRepeat.execute()

  select: ->
    _.times @count, => @operatorToRepeat.select()

class Delete
  motion: null
  complete: null

  constructor: (@editor) ->
    @complete = false

  isComplete: -> @complete

  execute: ->
    if @motion
      @motion.select()
      @editor.getSelection().delete()
    else
      @editor.buffer.deleteRow(@editor.getCursorRow())
      @editor.setCursorScreenPosition([@editor.getCursorRow(), 0])

  compose: (motion) ->
    if not motion.select
      throw new OperatorError("Delete must compose with a motion")

    @motion = motion
    @complete = true

module.exports = { NumericPrefix, Delete, OperatorError }

