Range = require 'range'

module.exports =
class AceOutdentAdaptor
  constructor: (@buffer, @editor) ->

  getLine: (row) ->
    @buffer.getLine(row)

  # We don't care where the bracket is; we always outdent one level
  findMatchingBracket: ({row, column}) ->
    {row: 0, column: 0}

  # Does not actually replace text, just line at range.start outdents one level
  replace: (range, text) ->
    {row, column} = @editor.getCursorBufferPosition()
    start = range.start
    end = {row: range.start.row, column: range.start.column + atom.tabText.length}
    @buffer.change(new Range(start, end), "")
    @editor.setCursorBufferPosition({row, column: column - atom.tabText.length})

