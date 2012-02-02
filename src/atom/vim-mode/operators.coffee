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
      @editor.deleteLine()

  compose: (motion) ->
    @motion = motion
    @complete = true

module.exports = { NumericPrefix, Delete }

