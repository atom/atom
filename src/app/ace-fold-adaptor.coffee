module.exports =
class AceFoldAdaptor
  foldWidgets: {}

  constructor: (@highlighter) ->
    @buffer = @highlighter.buffer

  getLine: (bufferRow) ->
    @buffer.lineForRow(bufferRow)

  getLength: ->
    @buffer.getLineCount()

  $findClosingBracket: (bracketType, bufferPosition) ->
    @highlighter.findClosingBracket([bufferPosition.row, bufferPosition.column - 1])

