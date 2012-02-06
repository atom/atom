{View} = require 'space-pen'
Point = require 'point'
_ = require 'underscore'

module.exports =
class Cursor extends View
  @content: ->
    @pre class: 'cursor idle', style: 'position: absolute;', => @raw '&nbsp;'

  editor: null

  initialize: (@editor) ->
    @one 'attach', => @updateAppearance()

  bufferChanged: (e) ->
    @setPosition(e.postRange.end)

  setPosition: (point) ->
    point = Point.fromObject(point)
    @point = @editor.clipPosition(point)
    @goalColumn = null
    @updateAppearance()
    @trigger 'cursor:position-changed'

    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  getPosition: -> _.clone(@point)

  setColumn: (column) ->
    { row } = @getPosition()
    @setPosition {row, column}

  getColumn: ->
    @getPosition().column

  getRow: ->
    @getPosition().row

  moveUp: ->
    { row, column } = @getPosition()
    column = @goalColumn if @goalColumn?
    if row > 0
      @setPosition({row: row - 1, column: column})
    else
      @moveToLineStart()

    @goalColumn = column

  moveDown: ->
    { row, column } = @getPosition()
    column = @goalColumn if @goalColumn?
    if row < @editor.buffer.numLines() - 1
      @setPosition({row: row + 1, column: column})
    else
      @moveToLineEnd()

    @goalColumn = column

  moveToLineEnd: ->
    { row } = @getPosition()
    @setPosition({ row, column: @editor.buffer.getLine(row).length })

  moveToLineStart: ->
    { row } = @getPosition()
    @setPosition({ row, column: 0 })

  moveRight: ->
    { row, column } = @getPosition()
    if column < @editor.buffer.getLine(row).length
      column++
    else if row < @editor.buffer.numLines() - 1
      row++
      column = 0
    @setPosition({row, column})

  moveLeft: ->
    { row, column } = @getPosition()
    if column > 0
      column--
    else if row > 0
      row--
      column = @editor.buffer.getLine(row).length

    @setPosition({row, column})

  updateAppearance: ->
    position = @editor.pixelPositionFromPoint(@point)
    @css(position)
    @autoScrollVertically(position)
    @autoScrollHorizontally(position)

  autoScrollVertically: (position) ->
    linesInView = @editor.height() / @height()
    maxScrollMargin = Math.floor((linesInView - 1) / 2)
    scrollMargin = Math.min(@editor.vScrollMargin, maxScrollMargin)
    margin = scrollMargin * @height()
    desiredTop = position.top - margin
    desiredBottom = position.top + @height() + margin

    if desiredBottom > @editor.scrollBottom()
      @editor.scrollBottom(desiredBottom)
    else if desiredTop < @editor.scrollTop()
      @editor.scrollTop(desiredTop)

  autoScrollHorizontally: (position) ->
    charsInView = @editor.width() / @width()
    maxScrollMargin = Math.floor((charsInView - 1) / 2)
    scrollMargin = Math.min(@editor.hScrollMargin, maxScrollMargin)
    margin = scrollMargin * @width()
    desiredRight = position.left + @width() + margin
    desiredLeft = position.left - margin

    if desiredRight > @editor.scrollRight()
      @editor.scrollRight(desiredRight)
    else if desiredLeft < @editor.scrollLeft()
      @editor.scrollLeft(desiredLeft)

