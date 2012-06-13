module.exports =
class AceFoldAdaptor
  foldWidgets: {}

  constructor: (@languageMode) ->
    @buffer = @languageMode.buffer

  getLine: (bufferRow) ->
    @buffer.lineForRow(bufferRow)

  getLength: ->
    @buffer.getLineCount()

  $findClosingBracket: (bracketType, bufferPosition) ->
    @languageMode.findClosingBracket([bufferPosition.row, bufferPosition.column - 1])

