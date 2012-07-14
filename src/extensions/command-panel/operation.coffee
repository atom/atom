module.exports =
class Operation
  constructor: ({@buffer, bufferRange, @newText, @preserveSelection}) ->
    @anchorRange = @buffer.addAnchorRange(bufferRange)

  getBufferRange: ->
    @anchorRange.getBufferRange()

  execute: (editSession) ->
    @buffer.change(@getBufferRange(), @newText) if @newText
    editSession.addSelectionForBufferRange(@getBufferRange()) unless @preserveSelection

  destroy: ->
    @anchorRange.destroy()