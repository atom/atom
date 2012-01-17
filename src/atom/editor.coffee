Template = require 'template'
Buffer = require 'buffer'
Cursor = require 'cursor'
$ = require 'jquery'

module.exports =
class Editor extends Template
  content: ->
    @div class: 'editor', =>
      @div outlet: 'lines'
      @subview 'cursor', Cursor.build()

  viewProperties:
    buffer: null

    initialize: () ->
      @setBuffer(new Buffer)

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
      @lines.css('line-height')

    charWidth: ->
      return @cachedCharWidth if @cachedCharWidth
      fragment = $('<pre style="position: absolute; visibility: hidden;">x</pre>')
      @lines.append(fragment)
      @cachedCharWidth = fragment.width()
      fragment.remove()
      @cachedCharWidth

