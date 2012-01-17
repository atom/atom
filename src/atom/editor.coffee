Template = require 'template'
Buffer = require 'buffer'
Cursor = require 'cursor'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Editor extends Template
  content: ->
    @div class: 'editor', =>
      # @link rel: 'stylesheet', href: "#{require.resolve('editor.css')}?#{(new Date).getTime()}"
      @style       @div outlet: 'lines'
      @subview 'cursor', Cursor.build()

  viewProperties:
    buffer: null

    initialize: () ->
      $('head').append """
<style>
.editor {
  font-family: Inconsolata, Monaco, Courier;
  font: 18px Inconsolata, Monaco, Courier !important;
  position: relative;
  width: 100%;
  height: 100%;
  background: #333;
  color: white;
}

.editor pre {
  margin: 0;
}

.editor .cursor {
  background: #9dff9d;
  opacity: .3;
}
</style>

      """

      @setBuffer(new Buffer)

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
      @calculateDimensions() unless @cachedLineHeight
      @cachedLineHeight

    charWidth: ->
      @calculateDimensions() unless @cachedCharWidth
      @cachedCharWidth

    calculateDimensions: ->
      fragment = $('<pre style="position: absolute; visibility: hidden;">x</pre>')
      @lines.append(fragment)
      @cachedCharWidth = fragment.width()
      @cachedLineHeight = fragment.outerHeight()
      console.log @cachedLineHeight
      fragment.remove()

