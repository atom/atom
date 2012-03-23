{View} = require 'space-pen'
Point = require 'point'
_ = require 'underscore'

module.exports =
class Cursor extends View
  @content: ->
    @pre class: 'cursor idle', => @raw '&nbsp;'

  editor: null
  screenPosition: null
  bufferPosition: null

  initialize: (@editor) ->
    @screenPosition = new Point(0, 0)
    @one 'attach', => @updateAppearance()

  handleBufferChange: (e) ->
    { newRange, oldRange } = e
    if oldRange.end.row == newRange.end.row == @getBufferPosition().row
      delta = newRange.end.subtract(oldRange.end)
      @setBufferPosition(@getBufferPosition().add(delta))

  setScreenPosition: (position, options={}) ->
    position = Point.fromObject(position)
    clip = options.clip ? true

    @screenPosition = if clip then @editor.clipScreenPosition(position) else position
    @bufferPosition = @editor.bufferPositionForScreenPosition(position)

    Object.freeze @screenPosition
    Object.freeze @bufferPosition

    @goalColumn = null
    @updateAppearance()
    @trigger 'cursor:position-changed'

    @removeClass 'idle'
    window.clearTimeout(@idleTimeout) if @idleTimeout
    @idleTimeout = window.setTimeout (=> @addClass 'idle'), 200

  setBufferPosition: (bufferPosition) ->
    @setScreenPosition(@editor.screenPositionForBufferPosition(bufferPosition), clip: false)

  refreshScreenPosition: ->
    @setBufferPosition(@bufferPosition)

  getBufferPosition: ->
    @bufferPosition

  getScreenPosition: ->
    @screenPosition

  getBufferColumn: ->
    @getBufferPosition().column

  setBufferColumn: (column) ->
    { row } = @getBufferPosition()
    @setBufferPosition {row, column}

  getScreenColumn: ->
    @getScreenPosition().column

  setScreenColumn: (column) ->
    { row } = @getScreenPosition()
    @setScreenPosition {row, column}

  getScreenRow: ->
    @getScreenPosition().row

  getBufferRow: ->
    @getBufferPosition().row

  isOnEOL: ->
    @getScreenColumn() == @editor.getCurrentScreenLine().length

  moveUp: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row - 1, column: column})
    @goalColumn = column

  moveDown: ->
    { row, column } = @getScreenPosition()
    column = @goalColumn if @goalColumn?
    @setScreenPosition({row: row + 1, column: column})
    @goalColumn = column

  moveToLineEnd: ->
    { row } = @getScreenPosition()
    @setScreenPosition({ row, column: @editor.buffer.lineForRow(row).length })

  moveToLineStart: ->
    { row } = @getScreenPosition()
    @setScreenPosition({ row, column: 0 })

  moveRight: ->
    { row, column } = @getScreenPosition()
    @setScreenPosition(@editor.clipScreenPosition([row, column + 1], skipAtomicTokens: true, wrapBeyondNewlines: true, wrapAtSoftNewlines: true))

  moveLeft: ->
    { row, column } = @getScreenPosition()

    if column > 0
      column--
    else
      row--
      column = Infinity

    @setScreenPosition({row, column})

  moveLeftUntilMatch: (regex) ->
    row = @getScreenRow()
    column = @getScreenColumn()
    offset = 0

    matchBackwards = =>
      line = @editor.buffer.lineForRow(row)
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
    _.defer =>
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
    return if @editor.softWrap

    charsInView = @editor.horizontalScroller.width() / @width()
    maxScrollMargin = Math.floor((charsInView - 1) / 2)
    scrollMargin = Math.min(@editor.hScrollMargin, maxScrollMargin)
    margin = scrollMargin * @width()
    desiredRight = position.left + @width() + margin
    desiredLeft = position.left - margin

    if desiredRight > @editor.horizontalScroller.scrollRight()
      @editor.horizontalScroller.scrollRight(desiredRight)
    else if desiredLeft < @editor.horizontalScroller.scrollLeft()
      @editor.horizontalScroller.scrollLeft(desiredLeft)

