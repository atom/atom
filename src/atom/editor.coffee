Template = require 'template'
Buffer = require 'buffer'
Selection = require 'selection'
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
    selection: null
    scrollMargin: 2

    initialize: () ->
      requireStylesheet 'editor.css'
      @bindKeys()
      @selection = Selection.build(this)
      @append(@selection)
      @handleEvents()
      @setBuffer(new Buffer)

    bindKeys: ->
      atom.bindKeys '*',
        right: 'move-right'
        left: 'move-left'
        down: 'move-down'
        up: 'move-up'
        enter: 'newline'
        backspace: 'backspace'

      @on 'move-right', => @moveCursorRight()
      @on 'move-left', => @moveCursorLeft()
      @on 'move-down', => @moveCursorDown()
      @on 'move-up', => @moveCursorUp()
      @on 'newline', =>  @insertNewline()
      @on 'backspace', => @backspace()

    handleEvents: ->
      @on 'focus', =>
        @hiddenInput.focus()
        false

      @hiddenInput.on "textInput", (e) =>
        @insertText(e.originalEvent.data)

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

      @setCursorPosition(row: 0, column: 0)

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

        @selection.bufferChanged(e)

    updateLineElement: (row) ->
      line = @buffer.getLine(row)
      element = @getLineElement(row)
      if line == ''
        element.html('&nbsp;')
      else
        element.text(line)

    insertLineElement: (row) ->
      @getLineElement(row).before(@buildLineElement(@buffer.getLine(row)))

    removeLineElement: (row) ->
      @getLineElement(row).remove()

    getLineElement: (row) ->
      @lines.find("pre:eq(#{row})")

    clipPosition: ({row, column}) ->
      line = @buffer.getLine(row)
      { row: row, column: Math.min(line.length, column) }

    pixelPositionFromPoint: ({row, column}) ->
      { top: row * @lineHeight, left: column * @charWidth }

    calculateDimensions: ->
      fragment = $('<pre style="position: absolute; visibility: hidden;">x</pre>')
      @lines.append(fragment)
      @charWidth = fragment.width()
      @lineHeight = fragment.outerHeight()
      fragment.remove()
      @selection.updateScreenPosition()

    scrollBottom: (newValue) ->
      if newValue?
        @scrollTop(newValue - @height())
      else
        @scrollTop() + @height()

    getCurrentLine: -> @buffer.getLine(@getCursorRow())
    getCursor: -> @selection.cursor
    moveCursorUp: -> @selection.moveCursorUp()
    moveCursorDown: -> @selection.moveCursorDown()
    moveCursorRight: -> @selection.moveCursorRight()
    moveCursorLeft: -> @selection.moveCursorLeft()
    setCursorPosition: (point) -> @selection.setCursorPosition(point)
    getCursorPosition: -> @selection.getCursorPosition()
    setCursorRow: (row) -> @selection.setCursorRow(row)
    getCursorRow: -> @selection.getCursorRow()
    setCursorColumn: (column) -> @selection.setCursorColumn(column)
    getCursorColumn: -> @selection.getCursorColumn()

    insertText: (text) -> @selection.insertText(text)
    insertNewline: -> @selection.insertNewline()
    backspace: -> @selection.backspace()

