Point = require 'point'

module.exports =
class Anchor
  editor: null
  bufferPosition: null
  screenPosition: null

  constructor: (editor) ->
    @editor = editor
    @bufferPosition = new Point(0, 0)
    @screenPosition = new Point(0, 0)

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

  setBufferPosition: (position) ->
    screenPosition = @editor.screenPositionForBufferPosition(position)
    @setScreenPosition(screenPosition, clip: false)

  getScreenPosition: ->
    @screenPosition

  setScreenPosition: (position, options={}) ->
    position = Point.fromObject(position)
    clip = options.clip ? true

    @screenPosition = if clip then @editor.clipScreenPosition(position) else position
    @bufferPosition = @editor.bufferPositionForScreenPosition(position)

    Object.freeze @screenPosition
    Object.freeze @bufferPosition