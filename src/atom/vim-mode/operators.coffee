_ = require 'underscore'

class NumericPrefix
  count: null
  complete: null
  operatorToRepeat: null

  constructor: (@count) ->
    @complete = false

  isComplete: -> @complete

  compose: (@operatorToRepeat) ->
    @complete = true

  addDigit: (digit) ->
    @count = @count * 10 + digit

  execute: (editor) ->
    _.times @count, => @operatorToRepeat.execute(editor)

  select: (editor) ->
    _.times @count, => @operatorToRepeat.select(editor)

class Delete
  motion: null
  complete: null

  constructor: ->
    @complete = false

  isComplete: -> @complete

  execute: (editor) ->
    if @motion
      @motion.select(editor)
      editor.delete()
    else
      editor.deleteLine()

  compose: (motion) ->
    @motion = motion
    @complete = true

module.exports = { NumericPrefix, Delete }

