{$$$} = require 'space-pen'

module.exports =
class Operation
  constructor: ({@project, @buffer, bufferRange, @newText, @preserveSelection, @errorMessage}) ->
    @buffer.retain()
    @marker = @buffer.markRange(bufferRange)

  getPath: ->
    @project.relativize(@buffer.getPath())

  getBufferRange: ->
    @buffer.getMarkerRange(@marker)

  execute: (editSession) ->
    @buffer.change(@getBufferRange(), @newText) if @newText
    @getBufferRange() unless @preserveSelection

  preview: ->
    range = @buffer.getMarkerRange(@marker)
    line = @buffer.lineForRow(range.start.row)
    prefix = line[0...range.start.column]
    match = line[range.start.column...range.end.column]
    suffix = line[range.end.column..]

    {prefix, suffix, match, range}

  destroy: ->
    @buffer.destroyMarker(@marker)
    @buffer.release()
