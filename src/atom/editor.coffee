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
      @input class: 'hidden-input', outlet: 'hiddenInput'

  viewProperties:
    buffer: null
    cursor: null
    scrollMargin: 2

    initialize: () ->
      requireStylesheet 'editor.css'

      @bindKeys()
      @attachCursor()
      @handleEvents()
      @setBuffer(new Buffer)

    attachCursor: ->
      @cursor = Cursor.build(this).appendTo(this)

    bindKeys: ->
      atom.bindKeys '*',
        right: 'move-right'
        left: 'move-left'
        down: 'move-down'
        up: 'move-up'
        enter: 'newline'

      @on 'move-right', => @moveRight()
      @on 'move-left', => @moveLeft()
      @on 'move-down', => @moveDown()
      @on 'move-up', => @moveUp()
      @on 'newline', => @buffer.insert @getPosition(), "\n"

    handleEvents: ->
      @on 'focus', =>
        @hiddenInput.focus()
        false

      @hiddenInput.on "textInput", (e) =>
        @buffer.insert(@getPosition(), e.originalEvent.data)

      @one 'attach', =>
        @calculateDimensions()
        @focus()

    buildLineElement: (lineText) ->
      if lineText is ''
        $$.pre -> @raw('&nbsp;')
      else
        $$.pre(lineText)

    setBuffer: (@buffer) ->
      @lines.empty()
      for line in @buffer.getLines()
        @lines.append @buildLineElement(line)

      @setPosition(row: 0, col: 0)
      @cursor.setBuffer(@buffer)

      @buffer.on 'insert', (e) =>
        {row} = e.range.start

        updatedLine = @buildLineElement(@buffer.getLine(row))
        @lines.find('pre').eq(row).replaceWith(updatedLine)
        if e.string == '\n'
          updatedLine.after @buildLineElement(@buffer.getLine(row + 1))

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

    getCurrentLine: -> @buffer.getLine(@getPosition().row)

    moveUp: -> @cursor.moveUp()
    moveDown: -> @cursor.moveDown()
    moveRight: -> @cursor.moveRight()
    moveLeft: -> @cursor.moveLeft()
    setPosition: (point) -> @cursor.setPosition(point)
    getPosition: -> @cursor.getPosition()
    setColumn: (column)-> @cursor.setColumn column
