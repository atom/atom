Point = require 'point'

module.exports =
class Anchor
  editor: null
  bufferPosition: null
  screenPosition: null

  constructor: (editor, screenPosition) ->
    @editor = editor

    if screenPosition
      @setScreenPosition(screenPosition)
    else
      @bufferPosition = new Point(0,0)
      @screenPosition = new Point(0,0)

  handleBufferChange: (e) ->
    { oldRange, newRange } = e
    position = @getBufferPosition()
    return if position.isLessThan(oldRange.end)

    newRow = newRange.end.row
    newColumn = newRange.end.column
    if position.row == oldRange.end.row
      newColumn += position.column - oldRange.end.column
    else
      newColumn = position.column
      newRow += position.row - oldRange.end.row

    @setBufferPosition [newRow, newColumn]

  getBufferPosition: ->
    @bufferPosition

  setBufferPosition: (position, options) ->
    @bufferPosition = Point.fromObject(position)
    screenPosition = @editor.screenPositionForBufferPosition(@bufferPosition, options)
    @setScreenPosition(screenPosition, clip: false, assignBufferPosition: false)

  getScreenPosition: ->
    @screenPosition

  setScreenPosition: (position, options={}) ->
    @screenPosition = Point.fromObject(position)
    clip = options.clip ? true
    assignBufferPosition = options.assignBufferPosition ? true

    @screenPosition = @editor.clipScreenPosition(@screenPosition, options) if clip
    @bufferPosition = @editor.bufferPositionForScreenPosition(@screenPosition, options) if assignBufferPosition

    Object.freeze @screenPosition
    Object.freeze @bufferPosition
