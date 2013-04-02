module.exports =
class Operation
  constructor: ({@project, @path, @buffer, @bufferRange, @lineText, @newText, @preserveSelection, @errorMessage}) ->
    if @buffer?
      @buffer.retain()
      @getMarker()

  getMarker: ->
    @marker ?= @getBuffer().markRange(@bufferRange)

  getBuffer: ->
    @buffer ?= @project.bufferForPath(@path).retain()

  getPath: ->
    path = @path ? @getBuffer().getPath()
    @project.relativize(path)

  getBufferRange: ->
    @getBuffer().getMarkerRange(@getMarker())

  execute: (editSession) ->
    @getBuffer().change(@getBufferRange(), @newText) if @newText
    @getBufferRange() unless @preserveSelection

  preview: ->
    range = @getBufferRange()
    prefix = @lineText[0...range.start.column]
    match = @lineText[range.start.column...range.end.column]
    suffix = @lineText[range.end.column..]

    {prefix, suffix, match, range}

  destroy: ->
    @buffer?.destroyMarker(@marker) if @marker?
    @buffer?.release()
