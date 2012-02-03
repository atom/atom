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
    preRange = e.preRange.copy()
    postRange = e.postRange.copy()

    previousState = @lines[preRange.end.row].state
    startState = @lines[postRange.start.row - 1]?.state or 'start'
    @lines[preRange.start.row..preRange.end.row] =
      @tokenizeRows(startState, postRange.start.row, postRange.end.row)

    for row in [postRange.end.row...@buffer.lastRow()]
      break if @lines[row].state == previousState
      nextRow = row + 1
      previousState = @lines[nextRow].state
      @lines[nextRow] = @tokenizeRow(@lines[row].state, nextRow)

      preRange.end.row++
      preRange.end.column = @buffer.getLine(nextRow).length
      postRange.end.row++
      postRange.end.column = @buffer.getLine(nextRow).length

    @trigger("change", {preRange, postRange})

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

  on: (eventName, handler) ->
    @eventHandlers ?= {}
    @eventHandlers[eventName] ?= []
    @eventHandlers[eventName].push(handler)

  trigger: (eventName, event) ->
    @eventHandlers?[eventName]?.forEach (handler) -> handler(event)
