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
    @setBufferPosition(e.newRange.end)

  setScreenPosition: (position) ->
    position = Point.fromObject(position)
    @screenPosition = @editor.clipScreenPosition(position)
    @goalColumn = null
    @updateAppearance()
    @trigger 'cursor:position-changed'

    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  setBufferPosition: (bufferPosition) ->
    @setScreenPosition(@editor.screenPositionForBufferPosition(bufferPosition))

  getBufferPosition: ->
    @editor.bufferPositionForScreenPosition(@getScreenPosition())

  getScreenPosition: -> _.clone(@screenPosition)

  getColumn: ->
    @getScreenPosition().column

  setColumn: (column) ->
    { row } = @getScreenPosition()
    @setScreenPosition {row, column}

  getRow: ->
    @getScreenPosition().row

  isOnEOL: ->
    @getColumn() == @editor.getCurrentLine().length

  moveUp: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    if row > 0
      @setScreenPosition({row: row - 1, column: column})
    else
      @moveToLineStart()

    @goalColumn = column

  moveDown: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    if row < @editor.buffer.numLines() - 1
      @setScreenPosition({row: row + 1, column: column})
    else
      @moveToLineEnd()

    @goalColumn = column

  moveToLineEnd: ->
    { row } = @getScreenPosition()
    @setScreenPosition({ row, column: @editor.buffer.getLine(row).length })

  moveToLineStart: ->
    { row } = @getScreenPosition()
    @setScreenPosition({ row, column: 0 })

  moveRight: ->
    { row, column } = @getScreenPosition()
    @setScreenPosition(@editor.clipScreenPosition([row, column + 1], true))

  moveLeft: ->
    { row, column } = @getScreenPosition()
    if column > 0
      column--
    else if row > 0
      row--
      column = @editor.buffer.getLine(row).length

    @setScreenPosition({row, column})

  moveLeftUntilMatch: (regex) ->
    row = @getRow()
    column = @getColumn()
    offset = 0

    matchBackwards = =>
      line = @editor.buffer.getLine(row)
      reversedLine = line[0...column].split('').reverse().join('')
      regex.exec reversedLine

    if not match = matchBackwards()
      if row > 0
        row--
        column = @editor.buffer.getLineLength(row)
        match = matchBackwards()
      else
        column = 0

    offset = match and -match[0].length or 0

    @setScreenPosition [row, column + offset]

  updateAppearance: ->
    position = @editor.pixelPositionForScreenPosition(@getScreenPosition())
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

