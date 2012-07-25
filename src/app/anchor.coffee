Point = require 'point'
EventEmitter = require 'event-emitter'
_ = require 'underscore'

module.exports =
class Anchor
  buffer: null
  editSession: null # optional
  bufferPosition: null
  screenPosition: null
  ignoreEqual: false
  strong: false

  constructor: (@buffer, options = {}) ->
    { @editSession, @ignoreEqual, @strong } = options

  handleBufferChange: (e) ->
    { oldRange, newRange } = e
    position = @getBufferPosition()

    if oldRange.containsPoint(position, exclusive: true)
      if @strong
        @setBufferPosition(oldRange.start)
      else
        @destroy()
      return

    if @ignoreEqual
      return if position.isLessThanOrEqual(oldRange.end)
    else
      return if position.isLessThan(oldRange.end)

    newRow = newRange.end.row
    newColumn = newRange.end.column
    if position.row == oldRange.end.row
      newColumn += position.column - oldRange.end.column
    else
      newColumn = position.column
      newRow += position.row - oldRange.end.row

    @setBufferPosition([newRow, newColumn], bufferChange: true)

  getBufferPosition: ->
    @bufferPosition

  setBufferPosition: (position, options={}) ->
    @bufferPosition = Point.fromObject(position)
    clip = options.clip ? true
    @bufferPosition = @buffer.clipPosition(@bufferPosition) if clip
    @refreshScreenPosition(options)

  getScreenPosition: ->
    @screenPosition

  setScreenPosition: (position, options={}) ->
    previousScreenPosition = @screenPosition
    @screenPosition = Point.fromObject(position)
    clip = options.clip ? true
    assignBufferPosition = options.assignBufferPosition ? true

    @screenPosition = @editSession.clipScreenPosition(@screenPosition, options) if clip
    @bufferPosition = @editSession.bufferPositionForScreenPosition(@screenPosition, options) if assignBufferPosition

    Object.freeze @screenPosition
    Object.freeze @bufferPosition

    unless @screenPosition.isEqual(previousScreenPosition)
      @trigger 'change-screen-position', @screenPosition, bufferChange: options.bufferChange

  refreshScreenPosition: (options={}) ->
    return unless @editSession
    screenPosition = @editSession.screenPositionForBufferPosition(@bufferPosition, options)
    @setScreenPosition(screenPosition, bufferChange: options.bufferChange, clip: false, assignBufferPosition: false)

  destroy: ->
    @buffer.removeAnchor(this)
    @editSession?.removeAnchor(this)
    @trigger 'destroy'
    @off()

_.extend(Anchor.prototype, EventEmitter)
