Template = require 'template'
Buffer = require 'buffer'
Point = require 'point'
Cursor = require 'cursor'
Selection = require 'selection'
Range = require 'range'
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
    vScrollMargin: 2
    hScrollMargin: 10
    cursor: null
    buffer: null
    selection: null
    lineHeight: null
    charWidth: null

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
        backspace: 'delete-left'
        delete: 'delete-right'
        'meta-x': 'cut'
        'meta-c': 'copy'
        'meta-v': 'paste'

      @on 'move-right', => @moveCursorRight()
      @on 'move-left', => @moveCursorLeft()
      @on 'move-down', => @moveCursorDown()
      @on 'move-up', => @moveCursorUp()
      @on 'select-right', => @selectRight()
      @on 'select-left', => @selectLeft()
      @on 'select-up', => @selectUp()
      @on 'select-down', => @selectDown()
      @on 'newline', =>  @insertNewline()
      @on 'delete-left', => @deleteLeft()
      @on 'delete-right', => @deleteRight()
      @on 'cut', => @cutSelection()
      @on 'copy', => @copySelection()
      @on 'paste', => @paste()

    buildCursorAndSelection: ->
      @cursor = Cursor.build(this)
      @append(@cursor)

      @selection = Selection.build(this)
      @append(@selection)

    handleEvents: ->
      @on 'focus', =>
        @hiddenInput.focus()
        false

      @on 'mousedown', (e) =>
        clickCount = e.originalEvent.detail

        if clickCount == 1
          @setCursorPosition @pointFromMouseEvent(e)
          moveHandler = (e) => @selectToPosition(@pointFromMouseEvent(e))
          @on 'mousemove', moveHandler
          $(document).one 'mouseup', => @off 'mousemove', moveHandler
        else if clickCount == 2
          @selection.selectWord()

      @hiddenInput.on "textInput", (e) =>
        @insertText(e.originalEvent.data)

      @on 'cursor:position-changed', =>
        @hiddenInput.css(@pixelPositionFromPoint(@cursor.getPosition()))

      @one 'attach', =>
        @calculateDimensions()
        @hiddenInput.width(@charWidth)
        @focus()

    buildLineElement: (lineText) ->
      if lineText is ''
        $$.pre class: "line", -> @raw('&nbsp;')
      else
        $$.pre class: "line", lineText

    setBuffer: (@buffer) ->
      @lines.empty()
      for line in @buffer.getLines()
        @lines.append @buildLineElement(line)

      @setCursorPosition(row: 0, column: 0)

      @buffer.on 'change', (e) =>
        { preRange, postRange } = e

        if postRange.end.row > preRange.end.row
          # update, then insert elements
          for row in [preRange.start.row..postRange.end.row]
            if row <= preRange.end.row
              @updateLineElement(row)
            else
              @insertLineElement(row)
        else
          # traverse in reverse... remove, then update elements
          for row in [preRange.end.row..preRange.start.row]
            if row > postRange.end.row
              @removeLineElement(row)
            else
              @updateLineElement(row)

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
      @lines.find("pre.line:eq(#{row})")

    clipPosition: ({row, column}) ->
      row = Math.min(Math.max(0, row), @buffer.numLines() - 1)
      column = Math.min(Math.max(0, column), @buffer.getLine(row).length)
      new Point(row, column)

    pixelPositionFromPoint: ({row, column}) ->
      { top: row * @lineHeight, left: column * @charWidth }

    pointFromPixelPosition: ({top, left}) ->
      { row: Math.floor(top / @lineHeight), column: Math.floor(left / @charWidth) }

    pointFromMouseEvent: (e) ->
      { pageX, pageY } = e
      @pointFromPixelPosition
        top: pageY - @lines.offset().top
        left: pageX - @lines.offset().left

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

    scrollRight: (newValue) ->
      if newValue?
        @scrollLeft(newValue - @width())
      else
        @scrollLeft() + @width()

    getCursor: -> @cursor
    getSelection: -> @selection

    getCurrentLine: -> @buffer.getLine(@getCursorRow())
    getSelectedText: -> @selection.getText()
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
    selectToPosition: (position) ->
      @selection.selectToPosition(position)

    insertText: (text) -> @selection.insertText(text)
    insertNewline: -> @selection.insertNewline()

    cutSelection: -> @selection.cut()
    copySelection: -> @selection.copy()
    paste: -> @selection.insertText(atom.native.readFromPasteboard())

    deleteLeft: ->
      @selectLeft() if @selection.isEmpty()
      @selection.delete()

    deleteRight: ->
      @selectRight() if @selection.isEmpty()
      @selection.delete()

