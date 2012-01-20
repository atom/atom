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


    moveRight: ->
      { row, col } = @getPosition()
      if col < @buffer.getLine(row).length
        col++
      else if row < @buffer.numLines() - 1
        row++
        col = 0
      @setPosition({row, col})

    moveDown: ->
      { row, col } = @getPosition()
      if row < @buffer.numLines() - 1
        row++
      else
        col = @buffer.getLine(row).length
      @setPosition({row, col})

    moveLeft: ->
      { row, col } = @getPosition()
      if col > 0
        col--
      else if row > 0
        row--
        col = @buffer.getLine(row).length

      @setPosition({row, col})

    moveUp: ->
      { row, col } = @getPosition()
      if row is 0
        col = 0
      else
        row--
      @setPosition({row, col})

    setBuffer: (@buffer) ->
      @lines.empty()
      for line in @buffer.getLines()
        if line is ''
          @lines.append $$.pre -> @raw('&nbsp;')
        else
          @lines.append $$.pre(line)
      @setPosition(row: 0, col: 0)

    setPosition: (position) ->
      @cursor.setPosition(position)

    getPosition: ->
      @cursor.getPosition()

    toPixelPosition: ({row, col}) ->
      { top: row * @lineHeight(), left: col * @charWidth() }

    lineHeight: ->
      @cachedLineHeight

    charWidth: ->
      @cachedCharWidth

    calculateDimensions: ->
      fragment = $('<pre style="position: absolute; visibility: hidden;">x</pre>')
      @lines.append(fragment)
      @cachedCharWidth = fragment.width()
      @cachedLineHeight = fragment.outerHeight()
      fragment.remove()
      @cursor.updateAbsolutePosition()

