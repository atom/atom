Range = require 'range'

module.exports =
class AnchorRange
  start: null
  end: null
  buffer: null
  editSession: null # optional

  constructor: (bufferRange, @buffer, @editSession) ->
    bufferRange = Range.fromObject(bufferRange)
    @startAnchor = @buffer.addAnchorAtPosition(bufferRange.start, ignoreChangesStartingOnAnchor: true)
    @endAnchor = @buffer.addAnchorAtPosition(bufferRange.end)

  getBufferRange: ->
    new Range(@startAnchor.getBufferPosition(), @endAnchor.getBufferPosition())

  getScreenRange: ->
    new Range(@startAnchor.getScreenPosition(), @endAnchor.getScreenPosition())

  containsBufferPosition: (bufferPosition) ->
    @getBufferRange().containsPoint(bufferPosition)

  destroy: ->
    @startAnchor.destroy()
    @endAnchor.destroy()
    @buffer.removeAnchorRange(this)
    @editSession?.removeAnchorRange(this)
