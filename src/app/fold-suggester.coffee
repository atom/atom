AceFoldAdaptor = require 'ace-fold-adaptor'

module.exports =
class FoldSuggester
  constructor: (@languageMode) ->
    @buffer = @languageMode.buffer
    @aceFoldMode = @buffer.getMode().foldingRules
    @aceFoldAdaptor = new AceFoldAdaptor(@languageMode)

  isBufferRowFoldable: (bufferRow) ->
    @aceFoldMode?.getFoldWidget(@aceFoldAdaptor, null, bufferRow) == "start"

  rowRangeForFoldAtBufferRow: (bufferRow) ->
    if aceRange = @aceFoldMode?.getFoldWidgetRange(@aceFoldAdaptor, null, bufferRow)
      [aceRange.start.row, aceRange.end.row]
    else
      null
