module.exports =
class AceFoldAdaptor
  foldWidgets: {}

  constructor: (@highlighter) ->
    @buffer = @highlighter.buffer

  getLine: (bufferRow) ->
    @buffer.lineForRow(bufferRow)

  $findClosingBracket: (bracketType, bufferPosition) ->
    @highlighter.findClosingBracket([bufferPosition.row, bufferPosition.column - 1])

