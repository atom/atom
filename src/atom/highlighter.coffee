_ = require 'underscore'

module.exports =
class Highlighter
  buffer: null
  tokenizer: null
  lines: []

  constructor: (@buffer) ->
    @buildTokenizer()
    @lines = @tokenizeRows('start', 0, @buffer.lastRow())
    @buffer.on 'change', (e) => @handleBufferChange(e)

  buildTokenizer: ->
    Mode = require("ace/mode/#{@buffer.modeName()}").Mode
    @tokenizer = (new Mode).getTokenizer()

  handleBufferChange: (e) ->
    { preRange, postRange } = e

    previousState = @lines[preRange.end.row].state

    newLines = @tokenizeRows('start', postRange.start.row, postRange.end.row)
    @lines[preRange.start.row..preRange.end.row] = newLines

    row = postRange.end.row + 1
    state = _.last(newLines).state
    until state == previousState
      previousState = @lines[row].state
      @lines[row] = line = @tokenizeRow(state, row)
      { state } = line
      row++

  tokenizeRows: (state, start, end) ->
    for row in [start..end]
      line = @tokenizeRow(state, row)
      state = line.state
      line

  tokenizeRow: (state, row) ->
    @tokenizer.getLineTokens(@buffer.getLine(row), state)

  tokensForRow: (row) ->
    @lines[row].tokens

