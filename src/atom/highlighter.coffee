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
    oldRange = e.oldRange.copy()
    newRange = e.newRange.copy()
    previousState = @lines[oldRange.end.row].state # used in spill detection below

    startState = @lines[newRange.start.row - 1]?.state or 'start'
    @lines[oldRange.start.row..oldRange.end.row] =
      @tokenizeRows(startState, newRange.start.row, newRange.end.row)

    # spill detection
    # compare scanner state of last re-highlighted line with its previous state.
    # if it differs, re-tokenize the next line with the new state and repeat for
    # each line until the line's new state matches the previous state. this covers
    # cases like inserting a /* needing to comment out lines below until we see a */
    for row in [newRange.end.row...@buffer.lastRow()]
      break if @lines[row].state == previousState
      nextRow = row + 1
      previousState = @lines[nextRow].state
      @lines[nextRow] = @tokenizeRow(@lines[row].state, nextRow)

    # if highlighting spilled beyond the bounds of the textual change, update
    # the pre and post range to reflect area of highlight changes
    if nextRow > newRange.end.row
      oldRange.end.row += (nextRow - newRange.end.row)
      newRange.end.row = nextRow
      endColumn = @buffer.getLine(nextRow).length
      newRange.end.column = endColumn
      oldRange.end.column = endColumn

    @trigger("change", {oldRange, newRange})

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
