Template = require 'template'

module.exports =
class Cursor extends Template
  content: ->
    @pre class: 'cursor', style: 'position: absolute;', => @raw '&nbsp;'

  viewProperties:
    editor: ->
      @parentView

    setBuffer: (@buffer) ->
      @buffer.on 'insert', (e) =>
        @setY(@getY() + e.string.length)

    setPosition: (point) ->
      @point = @editor().clipPosition(point)
      @goalY = null
      @updateAbsolutePosition()

    getPosition: -> @point

    setY: (y) ->
      { x } = @getPosition()
      @setPosition {x, y}

    getY: ->
      @getPosition().y

    moveUp: ->
      { x, y } = @getPosition()
      y = @goalY if @goalY?
      if x > 0
        @setPosition({x: x - 1, y: y})
      else
        @moveToLineStart()

      @goalY = y

    moveDown: ->
      { x, y } = @getPosition()
      y = @goalY if @goalY?
      if x < @editor().buffer.numLines() - 1
        @setPosition({x: x + 1, y: y})
      else
        @moveToLineEnd()

      @goalY = y

    moveToLineEnd: ->
      { x } = @getPosition()
      @setPosition({ x, y: @editor().buffer.getLine(x).length })

    moveToLineStart: ->
      { x } = @getPosition()
      @setPosition({ x, y: 0 })

    moveRight: ->
      { x, y } = @getPosition()
      if y < @editor().buffer.getLine(x).length
        y++
      else if x < @editor().buffer.numLines() - 1
        x++
        y = 0
      @setPosition({x, y})

    moveLeft: ->
      { x, y } = @getPosition()
      if y > 0
        y--
      else if x > 0
        x--
        y = @editor().buffer.getLine(x).length

      @setPosition({x, y})

    updateAbsolutePosition: ->
      position = @editor().pixelPositionFromPoint(@point)
      @css(position)

      linesInView = @editor().height() / @height()

      maxScrollMargin = Math.floor((linesInView - 1) / 2)
      scrollMargin = Math.min(@editor().scrollMargin, maxScrollMargin)
      margin = scrollMargin * @height()
      desiredTop = position.top - margin
      desiredBottom = position.top + @height() + margin

      if desiredBottom > @editor().scrollBottom()
        @editor().scrollBottom(desiredBottom)
      else if desiredTop < @editor().scrollTop()
        @editor().scrollTop(desiredTop)

