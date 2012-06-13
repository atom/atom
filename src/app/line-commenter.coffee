Range = require 'range'
AceLineCommentAdaptor = require 'ace-line-comment-adaptor'

module.exports =
class LineCommenter
  languageMode: null
  buffer: null
  aceMode: null

  constructor: (@languageMode) ->
    @buffer = @languageMode.buffer
    @aceMode = @buffer.getMode()
    @adaptor = new AceLineCommentAdaptor(@buffer)

  toggleLineCommentsInRange: (range) ->
    range = Range.fromObject(range)
    @aceMode.toggleCommentLines(@languageMode.stateForRow(range.start.row), @adaptor, range.start.row, range.end.row)
