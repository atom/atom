Range = require 'range'

module.exports =
class AceAdaptor
  foldWidgets: {}

  constructor: (@editSession) ->
    @buffer = @editSession.buffer

  getLine: (bufferRow) ->
    @buffer.lineForRow(bufferRow)

  getLength: ->
    @buffer.getLineCount()

  $findClosingBracket: (bracketType, bufferPosition) ->
    @editSession.tokenizedBuffer.findClosingBracket([bufferPosition.row, bufferPosition.column - 1])

  indentRows: (startRow, endRow, indentString) ->
    for row in [startRow..endRow]
      @buffer.insert([row, 0], indentString)

  replace: (range, text) ->
    range = Range.fromObject(range)
    @buffer.change(range, text)

  findMatchingBracket: ({row, column}) ->
    @editSession.tokenizedBuffer.findOpeningBracket([row, column])
