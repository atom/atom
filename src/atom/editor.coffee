Template = require 'template'
Buffer = require 'buffer'
Cursor = require 'cursor'
$ = require 'jquery'
$$ = require 'template/builder'
_ = require 'underscore'

module.exports =
class Editor extends Template
  content: ->
    @div class: 'editor', tabindex: -1, =>
      @div outlet: 'lines'
      @subview 'cursor', Cursor.build()

  viewProperties:
    buffer: null
    scrollMargin: 2

    initialize: () ->
      requireStylesheet 'editor.css'
      @setBuffer(new Buffer)

      atom.bindKeys '*',
        right: 'move-right'
        left: 'move-left'
        down: 'move-down'
        up: 'move-up'

      @on 'move-right', => @moveRight()
      @on 'move-left', => @moveLeft()
      @on 'move-down', => @moveDown()
      @on 'move-up', => @moveUp()

      @one 'attach', =>
        @calculateDimensions()

    setBuffer: (@buffer) ->
      @lines.empty()
      for line in @buffer.getLines()
        if line is ''
          @lines.append $$.pre -> @raw('&nbsp;')
        else
          @lines.append $$.pre(line)
      @setPosition(row: 0, col: 0)

    clipPosition: ({row, col}) ->
      line = @buffer.getLine(row)
      { row: row, col: Math.min(line.length, col) }

    pixelPositionFromPoint: ({row, col}) ->
      { top: row * @lineHeight, left: col * @charWidth }

    calculateDimensions: ->
      fragment = $('<pre style="position: absolute; visibility: hidden;">x</pre>')
      @lines.append(fragment)
      @charWidth = fragment.width()
      @lineHeight = fragment.outerHeight()
      fragment.remove()
      @cursor.updateAbsolutePosition()

    scrollBottom: (newValue) ->
      if newValue?
        @scrollTop(newValue - @height())
      else
        @scrollTop() + @height()

    moveUp: -> @cursor.moveUp()
    moveDown: -> @cursor.moveDown()
    moveRight: -> @cursor.moveRight()
    moveLeft: -> @cursor.moveLeft()
    setPosition: (point) -> @cursor.setPosition(point)
    getPosition: -> @cursor.getPosition()
    setColumn: (column)-> @cursor.setColumn column
