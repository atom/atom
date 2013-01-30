_ = require 'underscore'
Point = require 'point'

module.exports =
class AnchorPoint
  bufferPosition: null
  screenPosition: null
  ignoreSameLocationInserts: false
  surviveSurroundingChanges: false

  constructor: ({@id, @editSession, bufferPosition, @ignoreSameLocationInserts, @surviveSurroundingChanges}) ->
    @setBufferPosition(bufferPosition)

  handleBufferChange: (e) ->
    { oldRange, newRange } = e
    position = @getBufferPosition()

    if oldRange.containsPoint(position, exclusive: true)
      if @surviveSurroundingChanges
        @setBufferPosition(oldRange.start)
      else
        @invalidate()
      return
    return if @ignoreSameLocationInserts and position.isEqual(oldRange.start)
    return if position.isLessThan(oldRange.end)

    newRow = newRange.end.row
    newColumn = newRange.end.column
    if position.row == oldRange.end.row
      newColumn += position.column - oldRange.end.column
    else
      newColumn = position.column
      newRow += position.row - oldRange.end.row

    @setBufferPosition([newRow, newColumn])

  setBufferPosition: (position, options={}) ->
    @bufferPosition = Point.fromObject(position)
    clip = options.clip ? true
    @bufferPosition = @editSession.clipBufferPosition(@bufferPosition) if clip
    @refreshScreenPosition(options)

  getBufferPosition: ->
    @bufferPosition

  setScreenPosition: (position, options={}) ->
    oldScreenPosition = @screenPosition
    oldBufferPosition = @bufferPosition
    @screenPosition = Point.fromObject(position)
    clip = options.clip ? true
    assignBufferPosition = options.assignBufferPosition ? true

    @screenPosition = @editSession.clipScreenPosition(@screenPosition, options) if clip
    @bufferPosition = @editSession.bufferPositionForScreenPosition(@screenPosition, options) if assignBufferPosition

    Object.freeze @screenPosition
    Object.freeze @bufferPosition

#     unless @screenPosition.isEqual(oldScreenPosition)
#       @trigger 'moved',
#         oldScreenPosition: oldScreenPosition
#         newScreenPosition: @screenPosition
#         oldBufferPosition: oldBufferPosition
#         newBufferPosition: @bufferPosition
#         bufferChange: options.bufferChange

  getScreenPosition: ->
    @screenPosition

  getScreenRow: ->
    @screenPosition.row

  refreshScreenPosition: (options={}) ->
    return unless @editSession
    screenPosition = @editSession.screenPositionForBufferPosition(@bufferPosition, options)
    @setScreenPosition(screenPosition, bufferChange: options.bufferChange, clip: false, assignBufferPosition: false)

  invalidate: ->
    @editSession.removeAnchorPoint(@id)