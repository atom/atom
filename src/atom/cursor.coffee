Template = require 'template'

module.exports =
class Cursor extends Template
  content: ->
    @pre class: 'cursor', style: 'position: absolute;', => @raw '&nbsp;'

  viewProperties:
    editor: null

    initialize: (editor) ->
      @editor = editor

    bufferChanged: (e) ->
      @setPosition(e.postRange.end)

    setPosition: (point) ->
      @point = @editor.clipPosition(point)
      @goalColumn = null
      @updateAbsolutePosition()

    getPosition: -> @point

    setColumn: (col) ->
      { row } = @getPosition()
      @setPosition {row, col}

    getColumn: ->
      @getPosition().col

    getRow: ->
      @getPosition().row

    moveUp: ->
      { row, col } = @getPosition()
      col = @goalColumn if @goalColumn?
      if row > 0
        @setPosition({row: row - 1, col: col})
      else
        @moveToLineStart()

      @goalColumn = col

    moveDown: ->
      { row, col } = @getPosition()
      col = @goalColumn if @goalColumn?
      if row < @editor.buffer.numLines() - 1
        @setPosition({row: row + 1, col: col})
      else
        @moveToLineEnd()

      @goalColumn = col

    moveToLineEnd: ->
      { row } = @getPosition()
      @setPosition({ row, col: @editor.buffer.getLine(row).length })

    moveToLineStart: ->
      { row } = @getPosition()
      @setPosition({ row, col: 0 })

    moveRight: ->
      { row, col } = @getPosition()
      if col < @editor.buffer.getLine(row).length
        col++
      else if row < @editor.buffer.numLines() - 1
        row++
        col = 0
      @setPosition({row, col})

    moveLeft: ->
      { row, col } = @getPosition()
      if col > 0
        col--
      else if row > 0
        row--
        col = @editor.buffer.getLine(row).length

      @setPosition({row, col})

    updateAbsolutePosition: ->
      position = @editor.pixelPositionFromPoint(@point)
      @css(position)

      linesInView = @editor.height() / @height()

      maxScrollMargin = Math.floor((linesInView - 1) / 2)
      scrollMargin = Math.min(@editor.scrollMargin, maxScrollMargin)
      margin = scrollMargin * @height()
      desiredTop = position.top - margin
      desiredBottom = position.top + @height() + margin

      if desiredBottom > @editor.scrollBottom()
        @editor.scrollBottom(desiredBottom)
      else if desiredTop < @editor.scrollTop()
        @editor.scrollTop(desiredTop)

