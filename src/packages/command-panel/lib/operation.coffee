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
    range = @bufferRange
    prefix = @lineText[0...range.start.column + 1]
    match = @lineText[range.start.column + 1...range.end.column + 1]
    suffix = @lineText[range.end.column + 1..]

    {prefix, suffix, match, range}

  destroy: ->
    @buffer?.destroyMarker(@marker) if @marker?
    @buffer?.release()
