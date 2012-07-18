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
    editSession.addSelectionForBufferRange(@getBufferRange()) unless @preserveSelection

  preview: ->
    "sad :-("

  destroy: ->
    @buffer.release()
    @anchorRange.destroy()