_ = require 'underscore'
Point = require 'point'

module.exports =
class AnchorPoint
  position: null
  ignoreSameLocationInserts: false
  surviveSurroundingChanges: false

  constructor: ({@id, @buffer, position, @ignoreSameLocationInserts, @surviveSurroundingChanges}) ->
    @setPosition(position)

  tryToInvalidate: (oldRange) ->
    if oldRange.containsPoint(@getPosition(), exclusive: true)
      position = @getPosition()
      if @surviveSurroundingChanges
        @setPosition(oldRange.start)
      else
        @invalidate()
      [@id, position]

  handleBufferChange: (e) ->
    { oldRange, newRange } = e
    position = @getPosition()

    return if oldRange.containsPoint(position, exclusive: true)
    return if @ignoreSameLocationInserts and position.isEqual(oldRange.start)
    return if position.isLessThan(oldRange.end)

    newRow = newRange.end.row
    newColumn = newRange.end.column
    if position.row == oldRange.end.row
      newColumn += position.column - oldRange.end.column
    else
      newColumn = position.column
      newRow += position.row - oldRange.end.row

    @setPosition([newRow, newColumn])

  setPosition: (position, options={}) ->
    @position = Point.fromObject(position)
    clip = options.clip ? true
    @position = @buffer.clipPosition(@position) if clip

  getPosition: ->
    @position

  invalidate: (preserve) ->
    delete @buffer.validAnchorPointsById[@id]
    @buffer.invalidAnchorPointsById[@id] = this
