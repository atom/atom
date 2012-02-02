module.exports =
class Highlighter
  buffer: null
  tokenizer: null
  tokensByRow: []

  constructor: (@buffer) ->
    @buildTokenizer()
    @tokensByRow = @tokenizeRows('start', 0, @buffer.lastRow())

    @buffer.on 'change', (e) =>
      { preRange, postRange } = e
      postRangeTokens = @tokenizeRows('start', postRange.start.row, postRange.end.row)
      @tokensByRow[preRange.start.row..preRange.end.row] = postRangeTokens

  buildTokenizer: ->
    Mode = require("ace/mode/#{@buffer.modeName()}").Mode
    @tokenizer = (new Mode).getTokenizer()

  tokenizeRows: (state, start, end) ->
    for row in [start..end]
      { state, tokens } = @tokenizeRow(state, row)
      tokens

  tokenizeRow: (state, row) ->
    @tokenizer.getLineTokens(@buffer.getLine(row), state)

  tokensForRow: (row) ->
    @tokensByRow[row]

