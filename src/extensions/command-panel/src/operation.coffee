{$$$} = require 'space-pen'

module.exports =
class Operation
  constructor: ({@project, @buffer, bufferRange, @newText, @preserveSelection}) ->
    @buffer.retain()
    @anchorRange = @buffer.addAnchorRange(bufferRange)

  getPath: ->
    @project.relativize(@buffer.getPath())

  getBufferRange: ->
    @anchorRange.getBufferRange()

  execute: (editSession) ->
    @buffer.change(@getBufferRange(), @newText) if @newText
    @getBufferRange() unless @preserveSelection

  preview: ->
    range = @anchorRange.getBufferRange()
    line = @buffer.lineForRow(range.start.row)
    prefix = line[0...range.start.column]
    match = line[range.start.column...range.end.column]
    suffix = line[range.end.column..]

    {prefix, suffix, match}

  destroy: ->
    @buffer.release()
    @anchorRange.destroy()