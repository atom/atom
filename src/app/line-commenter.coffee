Range = require 'range'
AceLineCommentAdaptor = require 'ace-line-comment-adaptor'

module.exports =
class LineCommenter
  highlighter: null
  buffer: null
  aceMode: null

  constructor: (@highlighter) ->
    @buffer = @highlighter.buffer
    @aceMode = @buffer.getMode()
    @adaptor = new AceLineCommentAdaptor(@buffer)

  toggleLineCommentsInRange: (range) ->
    range = Range.fromObject(range)
    @aceMode.toggleCommentLines(@highlighter.stateForRow(range.start.row), @adaptor, range.start.row, range.end.row)
