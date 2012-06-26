Range = require 'range'

module.exports =
class AnchorRange
  start: null
  end: null

  constructor: (@editSession, bufferRange) ->
    bufferRange = Range.fromObject(bufferRange)
    @startAnchor = @editSession.addAnchorAtBufferPosition(bufferRange.start)
    @endAnchor = @editSession.addAnchorAtBufferPosition(bufferRange.end)

  getBufferRange: ->
    new Range(@startAnchor.getBufferPosition(), @endAnchor.getBufferPosition())

  getScreenRange: ->
    new Range(@startAnchor.getScreenPosition(), @endAnchor.getScreenPosition())

  destroy: ->
    @startAnchor.destroy()
    @endAnchor.destroy()