Range = require 'range'

module.exports =
class Address
  startRow: null
  endRow: null

  constructor: (start, end) ->
    @startRow = start - 1
    @endRow = end - 1

  execute: (editor) ->
    range = new Range([@startRow, 0], [@endRow, 0])
    editor.getSelection().setBufferRange(range)