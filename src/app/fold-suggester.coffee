AceFoldAdaptor = require 'ace-fold-adaptor'

module.exports =
class FoldSuggester
  constructor: (@buffer) ->
    @aceFoldMode = @buffer.getMode().foldingRules
    @aceFoldAdaptor = new AceFoldAdaptor(@buffer)

  isBufferRowFoldable: (bufferRow) ->
    @aceFoldMode.getFoldWidget(@aceFoldAdaptor, null, bufferRow) == "start"
