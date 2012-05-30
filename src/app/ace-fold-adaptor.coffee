module.exports =
class AceFoldAdaptor
  constructor: (@buffer) ->

  getLine: (bufferRow) ->
    @buffer.lineForRow(bufferRow)
