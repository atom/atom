Template = require 'template'
Buffer = require 'buffer'
Cursor = require 'cursor'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Editor extends Template
  content: ->
    @div class: 'editor', =>
      @style       @div outlet: 'lines'
      @subview 'cursor', Cursor.build()

  viewProperties:
    buffer: null

    initialize: () ->
      requireStylesheet 'editor.css'
      @setBuffer(new Buffer)
      @one 'attach', => @calculateDimensions()

    setBuffer: (@buffer) ->
      @lines.empty()
      for line in @buffer.getLines()
        @lines.append "<pre>#{line}</pre>"
      _.defer => @setPosition(row: 3, col: 4)

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

