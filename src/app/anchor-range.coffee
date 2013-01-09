Range = require 'range'
EventEmitter = require 'event-emitter'
Subscriber = require 'subscriber'
_ = require 'underscore'

module.exports =
class AnchorRange
  start: null
  end: null
  buffer: null
  editSession: null # optional
  destroyed: false

  constructor: (bufferRange, @buffer, @editSession) ->
    bufferRange = Range.fromObject(bufferRange)
    @startAnchor = @buffer.addAnchorAtPosition(bufferRange.start, ignoreChangesStartingOnAnchor: true)
    @endAnchor = @buffer.addAnchorAtPosition(bufferRange.end)
    @subscribe @startAnchor, 'destroyed', => @destroy()
    @subscribe @endAnchor, 'destroyed', => @destroy()

  getBufferRange: ->
    new Range(@startAnchor.getBufferPosition(), @endAnchor.getBufferPosition())

  getScreenRange: ->
    new Range(@startAnchor.getScreenPosition(), @endAnchor.getScreenPosition())

  containsBufferPosition: (bufferPosition) ->
    @getBufferRange().containsPoint(bufferPosition)

  destroy: ->
    return if @destroyed
    @unsubscribe()
    @startAnchor.destroy()
    @endAnchor.destroy()
    @buffer.removeAnchorRange(this)
    @editSession?.removeAnchorRange(this)
    @destroyed = true
    @trigger 'destroyed'

_.extend(AnchorRange.prototype, EventEmitter)
_.extend(AnchorRange.prototype, Subscriber)
