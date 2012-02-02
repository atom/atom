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

    for row in [postRange.end.row...@buffer.lastRow()]
      break if @lines[row].state == previousState
      nextRow = row + 1
      previousState = @lines[nextRow].state
      @lines[nextRow] = @tokenizeRow(@lines[row].state, nextRow)

  tokenizeRows: (startState, startRow, endRow) ->
    state = startState
    for row in [startRow..endRow]
      line = @tokenizeRow(state, row)
      state = line.state
      line

  tokenizeRow: (state, row) ->
    @tokenizer.getLineTokens(@buffer.getLine(row), state)

  tokensForRow: (row) ->
    @lines[row].tokens

