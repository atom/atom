Template = require 'template'

module.exports =
class Cursor extends Template
  content: ->
    @pre class: 'cursor', style: 'position: absolute;', => @raw '&nbsp;'

  viewProperties:
    setPosition: (point) ->
      @point = @parentView.clipPosition(point)
      @goalColumn = null
      @updateAbsolutePosition()

    getPosition: -> @point

    setColumn: (col) ->
      { row } = @getPosition()
      @setPosition {row, col}

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
      if row < @parentView.buffer.numLines() - 1
        @setPosition({row: row + 1, col: col})
      else
        @moveToLineEnd()

      @goalColumn = col

    moveToLineEnd: ->
      { row } = @getPosition()
      @setPosition({ row, col: @parentView.buffer.getLine(row).length })

    moveToLineStart: ->
      { row } = @getPosition()
      @setPosition({ row, col: 0 })

    moveRight: ->
      { row, col } = @getPosition()
      if col < @parentView.buffer.getLine(row).length
        col++
      else if row < @parentView.buffer.numLines() - 1
        row++
        col = 0
      @setPosition({row, col})

    moveLeft: ->
      { row, col } = @getPosition()
      if col > 0
        col--
      else if row > 0
        row--
        col = @parentView.buffer.getLine(row).length

      @setPosition({row, col})

    updateAbsolutePosition: ->
      position = @parentView.pixelPositionFromPoint(@point)
      @css(position)

