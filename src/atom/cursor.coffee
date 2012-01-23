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
      if row is 0
        col = 0
      else
        row--

      col = @goalColumn if @goalColumn
      @setPosition({row, col})
      @goalColumn ?= col

    moveDown: ->
      { row, col } = @getPosition()

      if row < @parentView.buffer.numLines() - 1
        row++
      else
        col = @parentView.buffer.getLine(row).length

      col = @goalColumn if @goalColumn
      @setPosition({row, col})
      @goalColumn ?= col

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

