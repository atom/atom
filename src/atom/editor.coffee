{View, $$} = require 'space-pen'
Buffer = require 'buffer'
Point = require 'point'
Cursor = require 'cursor'
Selection = require 'selection'
Highlighter = require 'highlighter'
LineWrapper = require 'line-wrapper'
UndoManager = require 'undo-manager'
Range = require 'range'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Editor extends View
  @content: ->
    @div class: 'editor', tabindex: -1, =>
      @div outlet: 'lines'
      @input class: 'hidden-input', outlet: 'hiddenInput'

  vScrollMargin: 2
  hScrollMargin: 10
  softWrap: false
  lineHeight: null
  charWidth: null
  cursor: null
  selection: null
  buffer: null
  highlighter: null
  lineWrapper: null
  undoManager: null

  initialize: () ->
    requireStylesheet 'editor.css'
    requireStylesheet 'theme/twilight.css'
    @bindKeys()
    @buildCursorAndSelection()
    @handleEvents()
    @setBuffer(new Buffer)

  bindKeys: ->
    atom.bindKeys '*:not(.editor *)',
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
      delete: 'delete'
      'meta-x': 'cut'
      'meta-c': 'copy'
      'meta-v': 'paste'
      'meta-z': 'undo'
      'meta-Z': 'redo'
      'alt-meta-w': 'toggle-soft-wrap'

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
    @on 'delete', => @delete()
    @on 'cut', => @cutSelection()
    @on 'copy', => @copySelection()
    @on 'paste', => @paste()
    @on 'undo', => @undo()
    @on 'redo', => @redo()
    @on 'toggle-soft-wrap', => @toggleSoftWrap()

  buildCursorAndSelection: ->
    @cursor = new Cursor(this)
    @append(@cursor)

    @selection = new Selection(this)
    @append(@selection)

  handleEvents: ->
    @on 'focus', =>
      @hiddenInput.focus()
      false

    @on 'mousedown', (e) =>
      clickCount = e.originalEvent.detail

      if clickCount == 1
        @setCursorPosition @pointFromMouseEvent(e)
      else if clickCount == 2
        @selection.selectWord()
      else if clickCount >= 3
        @selection.selectLine(@getCursorRow())

      @selectTextOnMouseMovement()

    @hiddenInput.on "textInput", (e) =>
      @insertText(e.originalEvent.data)

    @on 'cursor:position-changed', =>
      @hiddenInput.css(@pixelPositionFromPoint(@cursor.getPosition()))

    @one 'attach', =>
      @calculateDimensions()
      @hiddenInput.width(@charWidth)
      @setMaxLineLength() if @softWrap
      @focus()

  selectTextOnMouseMovement: ->
    moveHandler = (e) => @selectToPosition(@pointFromMouseEvent(e))
    @on 'mousemove', moveHandler
    $(document).one 'mouseup', => @off 'mousemove', moveHandler

  buildLineElement: (screenLine) ->
    { tokens } = screenLine
    $$ ->
      @pre class: 'line', =>
        if tokens.length
          for token in tokens
            @span { class: token.type.replace('.', ' ') }, token.value
        else
          @raw '&nbsp;'

  renderLines: ->
    @lines.empty()
    for screenLine in @lineWrapper.screenLines()
      @lines.append @buildLineElement(screenLine)

  setBuffer: (@buffer) ->
    @highlighter = new Highlighter(@buffer)
    @lineWrapper = new LineWrapper(Infinity, @highlighter)
    @undoManager = new UndoManager(@buffer)
    @renderLines()
    @setCursorPosition(row: 0, column: 0)

    @buffer.on 'change', (e) =>
      @cursor.bufferChanged(e)

    @lineWrapper.on 'change', (e) =>
      { oldRange, newRange } = e
      screenLines = @lineWrapper.screenLinesForRows(newRange.start.row, newRange.end.row)
      if newRange.end.row > oldRange.end.row
        # update, then insert elements
        for row in [newRange.start.row..newRange.end.row]
          if row <= oldRange.end.row
            @updateLineElement(row, screenLines.shift())
          else
            @insertLineElement(row, screenLines.shift())
      else
        # traverse in reverse... remove, then update elements
        screenLines.reverse()
        for row in [oldRange.end.row..oldRange.start.row]
          if row > newRange.end.row
            @removeLineElement(row)
          else
            @updateLineElement(row, screenLines.shift())

  updateLineElement: (row, screenLine) ->
    @getLineElement(row).replaceWith(@buildLineElement(screenLine))

  insertLineElement: (row, screenLine) ->
    newLineElement = @buildLineElement(screenLine)
    insertBefore = @getLineElement(row)
    if insertBefore.length
      insertBefore.before(newLineElement)
    else
      @lines.append(newLineElement)

  removeLineElement: (row) ->
    @getLineElement(row).remove()

  getLineElement: (row) ->
    @lines.find("pre.line:eq(#{row})")

  toggleSoftWrap: ->
    @setSoftWrap(not @softWrap)

  setMaxLineLength: ->
    maxLength =
      if @softWrap
        Math.floor(@width() / @charWidth)
      else
        Infinity

    @lineWrapper.setMaxLength(maxLength) if maxLength

  setSoftWrap: (@softWrap) ->
    @setMaxLineLength()
    if @softWrap
      @_setMaxLineLength = => @setMaxLineLength()
      $(window).on 'resize', @_setMaxLineLength
    else
      $(window).off 'resize', @_setMaxLineLength

  clipPosition: ({row, column}) ->
    if row > @buffer.lastRow()
      row = @buffer.lastRow()
      column = @buffer.getLine(row).length
    else
      row = Math.min(Math.max(0, row), @buffer.numLines() - 1)
      column = Math.min(Math.max(0, column), @buffer.getLine(row).length)

    new Point(row, column)

  pixelPositionFromPoint: (position) ->
    { row, column } = @lineWrapper.screenPositionForBufferPosition(position)
    { top: row * @lineHeight, left: column * @charWidth }

  pointFromPixelPosition: ({top, left}) ->
    screenPosition = new Point(Math.floor(top / @lineHeight), Math.floor(left / @charWidth))
    @lineWrapper.bufferPositionForScreenPosition screenPosition

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

  backspace: ->
    @selectLeft() if @selection.isEmpty()
    @selection.delete()

  delete: ->
    @selectRight() if @selection.isEmpty()
    @selection.delete()

  undo: ->
    @undoManager.undo()

  redo: ->
    @undoManager.redo()
