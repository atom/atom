AceFoldAdaptor = require 'ace-fold-adaptor'

module.exports =
class FoldSuggester
  constructor: (@highlighter) ->
    @buffer = @highlighter.buffer
    @aceFoldMode = @buffer.getMode().foldingRules
    @aceFoldAdaptor = new AceFoldAdaptor(@highlighter)

  isBufferRowFoldable: (bufferRow) ->
    @aceFoldMode?.getFoldWidget(@aceFoldAdaptor, null, bufferRow) == "start"

  rowRangeForFoldAtBufferRow: (bufferRow) ->
    if aceRange = @aceFoldMode?.getFoldWidgetRange(@aceFoldAdaptor, null, bufferRow)
      [aceRange.start.row + 1, aceRange.end.row]
    else
      null
