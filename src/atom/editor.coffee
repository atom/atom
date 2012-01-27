Template = require 'template'
Buffer = require 'buffer'
Point = require 'point'
Cursor = require 'cursor'
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
    cursor: null
    buffer: null
    selection: null
    scrollMargin: 2

    initialize: () ->
      requireStylesheet 'editor.css'
      @bindKeys()
      @buildCursorAndSelection()
      @handleEvents()
      @setBuffer(new Buffer)

    bindKeys: ->
      atom.bindKeys '*',
        right: 'move-right'
        left: 'move-left'
        down: 'move-down'
        up: 'move-up'
        'shift-right': 'select-right'
        'shift-left': 'select-left'
        'shift-up': 'select-up'
        'shift-down': 'select-down'
        enter: 'newline'
        backspace: 'backspace'

      @on 'move-right', => @moveCursorRight()
      @on 'move-left', => @moveCursorLeft()
      @on 'move-down', => @moveCursorDown()
      @on 'move-up', => @moveCursorUp()
      @on 'select-right', => @selectRight()
      @on 'select-left', => @selectLeft()
      @on 'select-up', => @selectUp()
      @on 'select-down', => @selectDown()
      @on 'newline', =>  @insertNewline()
      @on 'backspace', => @backspace()


    buildCursorAndSelection: ->
      @cursor = Cursor.build(this)
      @append(@cursor)

      @selection = Selection.build(this)
      @append(@selection)

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
      new Point(row, Math.min(@buffer.getLine(row).length, column))

    pixelPositionFromPoint: ({row, column}) ->
      { top: row * @lineHeight, left: column * @charWidth }

    calculateDimensions: ->
      fragment = $('<pre style="position: absolute; visibility: hidden;">x</pre>')
      @lines.append(fragment)
      @charWidth = fragment.width()
      @lineHeight = fragment.outerHeight()
      fragment.remove()

    scrollBottom: (newValue) ->
      if newValue?
        @scrollTop(newValue - @height())
      else
        @scrollTop() + @height()

    getCurrentLine: -> @buffer.getLine(@getCursorRow())
    getCursor: -> @selection.cursor
    moveCursorUp: -> @cursor.moveUp()
    moveCursorDown: -> @cursor.moveDown()
    moveCursorRight: -> @cursor.moveRight()
    moveCursorLeft: -> @cursor.moveLeft()
    setCursorPosition: (point) -> @cursor.setPosition(point)
    getCursorPosition: -> @cursor.getPosition()
    setCursorRow: (row) -> @cursor.setRow(row)
    getCursorRow: -> @cursor.getRow()
    setCursorColumn: (column) -> @cursor.setColumn(column)
    getCursorColumn: -> @cursor.getColumn()

    selectRight: -> @selection.selectRight()
    selectLeft: -> @selection.selectLeft()
    selectUp: -> @selection.selectUp()
    selectDown: -> @selection.selectDown()

    insertText: (text) -> @selection.insertText(text)
    insertNewline: -> @selection.insertNewline()
    backspace: -> @selection.backspace()

