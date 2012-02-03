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
    previousState = @lines[preRange.end.row].state # used in spill detection below

    startState = @lines[postRange.start.row - 1]?.state or 'start'
    @lines[preRange.start.row..preRange.end.row] =
      @tokenizeRows(startState, postRange.start.row, postRange.end.row)

    # spill detection
    # compare scanner state of last re-highlighted line with its previous state.
    # if it differs, re-tokenize the next line with the new state and repeat for
    # each line until the line's new state matches the previous state. this covers
    # cases like inserting a /* needing to comment out lines below until we see a */
    for row in [postRange.end.row...@buffer.lastRow()]
      break if @lines[row].state == previousState
      nextRow = row + 1
      previousState = @lines[nextRow].state
      @lines[nextRow] = @tokenizeRow(@lines[row].state, nextRow)

    # if highlighting spilled beyond the bounds of the textual change, update
    # the pre and post range to reflect area of highlight changes
    if nextRow > postRange.end.row
      preRange.end.row += (nextRow - postRange.end.row)
      postRange.end.row = nextRow
      endColumn = @buffer.getLine(nextRow).length
      postRange.end.column = endColumn
      preRange.end.column = endColumn

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
