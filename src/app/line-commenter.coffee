Range = require 'range'

module.exports =
class LineCommenter
  highlighter: null
  buffer: null
  aceMode: null

  constructor: (@highlighter) ->
    @buffer = @highlighter.buffer
    @aceMode = @buffer.getMode()

  toggleLineCommentsInRange: (range) ->
    range = Range.fromObject(range)

    @aceMode.tog

