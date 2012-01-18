Template = require 'template'
Buffer = require 'buffer'
Cursor = require 'cursor'
$ = require 'jquery'
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
      @setPosition({row, col: col + 1})

    moveDown: ->
      { row, col } = @getPosition()
      @setPosition({row: row + 1, col})

    moveLeft: ->
      { row, col } = @getPosition()
      @setPosition({row, col: col - 1})

    moveUp: ->
      { row, col } = @getPosition()
      @setPosition({row: row - 1, col})

    setBuffer: (@buffer) ->
      @lines.empty()
      for line in @buffer.getLines()
        @lines.append "<pre>#{line}</pre>"
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

