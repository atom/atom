module.exports =
class AceOutdentAdaptor
  constructor: (@editSession) ->
    @buffer = @editSession.buffer

  getLine: (row) ->
    @buffer.lineForRow(row)

  # We don't care where the bracket is; we always outdent one level
  findMatchingBracket: ({row, column}) ->
    {row: 0, column: 0}

  # Does not actually replace text; always outdents one level
  replace: (range, text) ->
    start = range.start
    end = {row: range.start.row, column: range.start.column + @editSession.tabText.length}
    @buffer.change([start, end], "")
