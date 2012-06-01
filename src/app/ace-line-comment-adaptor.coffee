Range = require 'range'

module.exports =
class AceLineCommentAdaptor
  constructor: (@buffer) ->

  getLine: (row) ->
    @buffer.lineForRow(row)

  indentRows: (startRow, endRow, indentString) ->
    for row in [startRow..endRow]
      @buffer.insert([row, 0], indentString)

  replace: (range, text) ->
    range = Range.fromObject(range)
    @buffer.change(range, text)
