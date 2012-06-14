module.exports =
class AceAdaptor
  foldWidgets: {}

  constructor: (@tokenizedBuffer) ->
    @buffer = @tokenizedBuffer.buffer

  getLine: (bufferRow) ->
    @buffer.lineForRow(bufferRow)

  getLength: ->
    @buffer.getLineCount()

  $findClosingBracket: (bracketType, bufferPosition) ->
    @tokenizedBuffer.findClosingBracket([bufferPosition.row, bufferPosition.column - 1])

  indentRows: (startRow, endRow, indentString) ->
    for row in [startRow..endRow]
      @buffer.insert([row, 0], indentString)

  replace: (range, text) ->
    range = Range.fromObject(range)
    @buffer.change(range, text)

  # We don't care where the bracket is; we always outdent one level
  findMatchingBracket: ({row, column}) ->
    {row: 0, column: 0}

  # Does not actually replace text; always outdents one level
  replace: (range, text) ->
    start = range.start
    end = {row: range.start.row, column: range.start.column + @tokenizedBuffer.tabText.length}
    @buffer.change([start, end], "")
