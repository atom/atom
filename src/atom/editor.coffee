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
        backspace: 'backspace'

      @on 'move-right', => @moveRight()
      @on 'move-left', => @moveLeft()
      @on 'move-down', => @moveDown()
      @on 'move-up', => @moveUp()
      @on 'newline', => @buffer.change({ start: @getPosition(), end: @getPosition() }, "\n")
      @on 'backspace', => @buffer.backspace @getPosition()

    handleEvents: ->
      @on 'focus', =>
        @hiddenInput.focus()
        false

      @hiddenInput.on "textInput", (e) =>
        @buffer.change({ start: @getPosition(), end: @getPosition() }, e.originalEvent.data)

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

      # @buffer.on 'insert', (e) =>
      #   {row} = e.range.start
      #   updatedLine = @buildLineElement(@buffer.getLine(row))
      #   @lines.find('pre').eq(row).replaceWith(updatedLine)
      #   if e.string == '\n'
      #     updatedLine.after @buildLineElement(@buffer.getLine(row + 1))

      @buffer.on 'change', (e) =>
        { preRange, postRange } = e

        curRow = preRange.start.row
        maxRow = Math.max(preRange.end.row, postRange.end.row)

        while curRow <= maxRow
          if curRow > postRange.end.row
            @removeLineElement(curRow)
          else if curRow > preRange.end.row
            @insertLineElement(curRow)
          else
            @updateLineElement(curRow)
          curRow++

        @cursor.bufferChanged(e)

    updateLineElement: (row) ->
      @getLineElement(row).replaceWith(@buildLineElement(@buffer.getLine(row)))

    insertLineElement: (row) ->
      @getLineElement(row).before(@buildLineElement(@buffer.getLine(row)))

    removeLineElement: (row) ->
      @getLineElement(row).remove()

    getLineElement: (row) ->
      @lines.find("pre:eq(#{row})")

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
