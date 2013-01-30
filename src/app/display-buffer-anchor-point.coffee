module.exports =
class DisplayBufferAnchorPoint
  bufferPosition: null
  screenPosition: null

  constructor: ({@displayBuffer, bufferPosition, screenPosition}) ->
    {@buffer} = @displayBuffer
    if screenPosition
      bufferPosition = @displayBuffer.bufferPositionForScreenPosition(screenPosition)

    @id = @buffer.createAnchorPoint(bufferPosition)

  getBufferPosition: ->
    @buffer.getAnchorPoint(@id)

