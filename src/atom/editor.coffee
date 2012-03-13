{View, $$} = require 'space-pen'
AceOutdentAdaptor = require 'ace-outdent-adaptor'
Buffer = require 'buffer'
Cursor = require 'cursor'
Gutter = require 'gutter'
Renderer = require 'renderer'
Point = require 'point'
Range = require 'range'
Selection = require 'selection'
UndoManager = require 'undo-manager'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Editor extends View
  @content: ->
    @div class: 'editor', tabindex: -1, =>
      @div class: 'content', outlet: 'content', =>
        @subview 'gutter', new Gutter
        @div class: 'horizontal-scroller', outlet: 'horizontalScroller', =>
          @div class: 'lines', outlet: 'lines', =>
            @input class: 'hidden-input', outlet: 'hiddenInput'

  vScrollMargin: 2
  hScrollMargin: 10
  softWrap: false
  lineHeight: null
  charWidth: null
  charHeight: null
  cursor: null
  selection: null
  buffer: null
  highlighter: null
  renderer: null
  undoManager: null
  autoIndent: null
  lineCache: null

  initialize: () ->
    requireStylesheet 'editor.css'
    requireStylesheet 'theme/twilight.css'
    @bindKeys()
    @buildCursorAndSelection()
    @handleEvents()
    @setBuffer(new Buffer)
    @autoIndent = true

  bindKeys: ->
    window.keymap.bindKeys '*:not(.editor *)',
      'meta-s': 'save'
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
      'delete': 'delete'
      'meta-x': 'cut'
      'meta-c': 'copy'
      'meta-v': 'paste'
      'meta-z': 'undo'
      'meta-Z': 'redo'
      'alt-meta-w': 'toggle-soft-wrap'
      'alt-meta-f': 'fold-selection'

    @on 'save', => @save()
    @on 'move-right', => @moveCursorRight()
    @on 'move-left', => @moveCursorLeft()
    @on 'move-down', => @moveCursorDown()
    @on 'move-up', => @moveCursorUp()
    @on 'select-right', => @selectRight()
    @on 'select-left', => @selectLeft()
    @on 'select-up', => @selectUp()
    @on 'select-down', => @selectDown()
    @on 'newline', =>  @insertText("\n")
    @on 'backspace', => @backspace()
    @on 'delete', => @delete()
    @on 'cut', => @cutSelection()
    @on 'copy', => @copySelection()
    @on 'paste', => @paste()
    @on 'undo', => @undo()
    @on 'redo', => @redo()
    @on 'toggle-soft-wrap', => @toggleSoftWrap()
    @on 'fold-selection', => @foldSelection()

  buildCursorAndSelection: ->
    @cursor = new Cursor(this)
    @lines.append(@cursor)

    @selection = new Selection(this)
    @lines.append(@selection)

  handleEvents: ->
    @on 'focus', =>
      @hiddenInput.focus()
      false

    @on 'mousedown', '.fold-placeholder', (e) =>
      @destroyFold($(e.currentTarget).attr('foldId'))
      false

    @on 'mousedown', (e) =>
      clickCount = e.originalEvent.detail

      if clickCount == 1
        @setCursorScreenPosition @screenPositionFromMouseEvent(e)
      else if clickCount == 2
        @selection.selectWord()
      else if clickCount >= 3
        @selection.selectLine()

      @selectTextOnMouseMovement()

    @hiddenInput.on "textInput", (e) =>
      @insertText(e.originalEvent.data)

    @on 'cursor:position-changed', =>
      @hiddenInput.css(@pixelPositionForScreenPosition(@cursor.getScreenPosition()))

    @one 'attach', =>
      @calculateDimensions()
      @hiddenInput.width(@charWidth)
      @setMaxLineLength() if @softWrap
      @focus()

  selectTextOnMouseMovement: ->
    moveHandler = (e) => @selectToScreenPosition(@screenPositionFromMouseEvent(e))
    @on 'mousemove', moveHandler
    $(document).one 'mouseup', => @off 'mousemove', moveHandler

  renderLines: ->
    @lineCache = []
    @lines.find('.line').remove()
    @insertLineElements(0, @buildLineElements(0, @lastRow()))

  getScreenLines: ->
    @renderer.getLines()

  linesForRows: (start, end) ->
    @renderer.linesForRows(start, end)

  screenLineCount: ->
    @renderer.lineCount()

  lastRow: ->
    @screenLineCount() - 1

  setBuffer: (@buffer) ->
    document.title = @buffer.path
    @renderer = new Renderer(@buffer)
    @undoManager = new UndoManager(@buffer)
    @renderLines()
    @gutter.renderLineNumbers()

    @setCursorScreenPosition(row: 0, column: 0)

    @buffer.on 'change', (e) => @cursor.bufferChanged(e)
    @renderer.on 'change', (e) => @handleRendererChange(e)

  handleRendererChange: (e) ->
    { oldRange, newRange } = e
    unless newRange.isSingleLine() and newRange.coversSameRows(oldRange)
      @gutter.renderLineNumbers(@getScreenLines())

    @cursor.refreshScreenPosition() unless e.bufferChanged

    lineElements = @buildLineElements(newRange.start.row, newRange.end.row)
    @replaceLineElements(oldRange.start.row, oldRange.end.row, lineElements)

  buildLineElements: (startRow, endRow) ->
    charWidth = @charWidth
    charHeight = @charHeight
    lines = @renderer.linesForRows(startRow, endRow)
    $$ ->
      for line in lines
        @div class: 'line', =>
          appendNbsp = true
          for token in line.tokens
            if token.type is 'fold-placeholder'
              @span '   ', class: 'fold-placeholder', style: "width: #{3 * charWidth}px; height: #{charHeight}px;", 'foldId': token.fold.id, =>
                @div class: "ellipsis", => @raw "&hellip;"
            else
              appendNbsp = false
              @span { class: token.type.replace('.', ' ') }, token.value
          @raw '&nbsp;' if appendNbsp

  insertLineElements: (row, lineElements) ->
    @spliceLineElements(row, 0, lineElements)

  replaceLineElements: (startRow, endRow, lineElements) ->
    @spliceLineElements(startRow, endRow - startRow + 1, lineElements)

  spliceLineElements: (startRow, rowCount, lineElements) ->
    endRow = startRow + rowCount
    elementToInsertBefore = @lineCache[startRow]
    elementsToReplace = @lineCache[startRow...endRow]
    @lineCache[startRow...endRow] = lineElements?.toArray() or []

    lines = @lines[0]
    if lineElements
      fragment = document.createDocumentFragment()
      lineElements.each -> fragment.appendChild(this)
      if elementToInsertBefore
        lines.insertBefore(fragment, elementToInsertBefore)
      else
        lines.appendChild(fragment)

    elementsToReplace.forEach (element) =>
      lines.removeChild(element)

  getLineElement: (row) ->
    @lineCache[row]

  toggleSoftWrap: ->
    @setSoftWrap(not @softWrap)

  setMaxLineLength: (maxLength) ->
    maxLength ?=
      if @softWrap
        Math.floor(@horizontalScroller.width() / @charWidth)
      else
        Infinity

    @renderer.setMaxLineLength(maxLength) if maxLength

  createFold: (range) ->
    @renderer.createFold(range)

  setSoftWrap: (@softWrap) ->
    @setMaxLineLength()
    if @softWrap
      @addClass 'soft-wrap'
      @_setMaxLineLength = => @setMaxLineLength()
      $(window).on 'resize', @_setMaxLineLength
    else
      @removeClass 'soft-wrap'
      $(window).off 'resize', @_setMaxLineLength

  save: ->
    if not @buffer.path
      path = $native.saveDialog()
      return if not path
      document.title = path
      @buffer.path = path

    @buffer.save()

  clipScreenPosition: (screenPosition, options={}) ->
    @renderer.clipScreenPosition(screenPosition, options)

  pixelPositionForScreenPosition: ({row, column}) ->
    { top: row * @lineHeight, left: column * @charWidth }

  screenPositionFromPixelPosition: ({top, left}) ->
    screenPosition = new Point(Math.floor(top / @lineHeight), Math.floor(left / @charWidth))

  screenPositionForBufferPosition: (position) ->
    @renderer.screenPositionForBufferPosition(position)

  bufferPositionForScreenPosition: (position) ->
    @renderer.bufferPositionForScreenPosition(position)

  screenRangeForBufferRange: (range) ->
    @renderer.screenRangeForBufferRange(range)

  bufferRangeForScreenRange: (range) ->
    @renderer.bufferRangeForScreenRange(range)

  bufferRowsForScreenRows: ->
    @renderer.bufferRowsForScreenRows()

  screenPositionFromMouseEvent: (e) ->
    { pageX, pageY } = e
    @screenPositionFromPixelPosition
      top: pageY - @horizontalScroller.offset().top
      left: pageX - @horizontalScroller.offset().left + @horizontalScroller.scrollLeft()

  calculateDimensions: ->
    fragment = $('<div class="line" style="position: absolute; visibility: hidden;"><span>x</span></div>')
    @lines.append(fragment)
    @charWidth = fragment.width()
    @charHeight = fragment.find('span').height()
    @lineHeight = fragment.outerHeight()
    fragment.remove()


  getCursor: -> @cursor
  moveCursorUp: -> @cursor.moveUp()
  moveCursorDown: -> @cursor.moveDown()
  moveCursorRight: -> @cursor.moveRight()
  moveCursorLeft: -> @cursor.moveLeft()

  getCurrentScreenLine: -> @buffer.lineForRow(@getCursorScreenRow())
  getCurrentBufferLine: -> @buffer.lineForRow(@getCursorBufferRow())
  setCursorScreenPosition: (position) -> @cursor.setScreenPosition(position)
  getCursorScreenPosition: -> @cursor.getScreenPosition()
  setCursorBufferPosition: (position) -> @cursor.setBufferPosition(position)
  getCursorBufferPosition: -> @cursor.getBufferPosition()
  setCursorScreenRow: (row) -> @cursor.setScreenRow(row)
  getCursorScreenRow: -> @cursor.getScreenRow()
  getCursorBufferRow: -> @cursor.getBufferRow()
  setCursorScreenColumn: (column) -> @cursor.setScreenColumn(column)
  getCursorScreenColumn: -> @cursor.getScreenColumn()
  setCursorBufferColumn: (column) -> @cursor.setBufferColumn(column)
  getCursorBufferColumn: -> @cursor.getBufferColumn()

  getSelection: -> @selection
  getSelectedText: -> @selection.getText()
  selectRight: -> @selection.selectRight()
  selectLeft: -> @selection.selectLeft()
  selectUp: -> @selection.selectUp()
  selectDown: -> @selection.selectDown()
  selectToScreenPosition: (position) -> @selection.selectToScreenPosition(position)
  selectToBufferPosition: (position) -> @selection.selectToBufferPosition(position)

  insertText: (text) ->
    { text, shouldOutdent } = @autoIndentText(text)
    @selection.insertText(text)
    @autoOutdentText() if shouldOutdent

  autoIndentText: (text) ->
    if @autoIndent
      row = @getCursorScreenPosition().row
      state = @renderer.lineForRow(row).state
      if text[0] == "\n"
        indent = @buffer.mode.getNextLineIndent(state, @getCurrentBufferLine(), atom.tabText)
        text = text[0] + indent + text[1..]
      else if @buffer.mode.checkOutdent(state, @getCurrentBufferLine(), text)
        shouldOutdent = true

    {text, shouldOutdent}

  autoOutdentText: ->
    screenRow = @getCursorScreenPosition().row
    bufferRow = @getCursorBufferPosition().row
    state = @renderer.lineForRow(screenRow).state
    @buffer.mode.autoOutdent(state, new AceOutdentAdaptor(@buffer, this), bufferRow)

  cutSelection: -> @selection.cut()
  copySelection: -> @selection.copy()
  paste: -> @insertText($native.readFromPasteboard())

  foldSelection: -> @selection.fold()

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

  destroyFold: (foldId) ->
    fold = @renderer.foldsById[foldId]
    fold.destroy()
    @setCursorBufferPosition(fold.start)

  logLines: ->
    @renderer.logLines()
