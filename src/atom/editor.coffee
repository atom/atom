{View, $$} = require 'space-pen'
AceOutdentAdaptor = require 'ace-outdent-adaptor'
Buffer = require 'buffer'
CompositeCursor = require 'composite-cursor'
CompositeSelection = require 'composite-selection'
Gutter = require 'gutter'
Renderer = require 'renderer'
Point = require 'point'
Range = require 'range'
EditSession = require 'edit-session'

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Editor extends View
  @idCounter: 1

  @content: ->
    @div class: 'editor', tabindex: -1, =>
      @div class: 'scrollable-content', =>
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
  autoIndent: null
  lineCache: null
  isFocused: false

  initialize: ({buffer}) ->
    requireStylesheet 'editor.css'
    requireStylesheet 'theme/twilight.css'
    @id = Editor.idCounter++
    @editSessionsByBufferId = {}
    @bindKeys()
    @buildCursorAndSelection()
    @handleEvents()
    @setBuffer(buffer ? new Buffer)
    @autoIndent = true

  bindKeys: ->
    window.keymap.bindKeys '.editor',
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
      'alt-meta-left': 'split-left'
      'alt-meta-right': 'split-right'
      'alt-meta-up': 'split-up'
      'alt-meta-down': 'split-down'

    @on 'save', => @save()
    @on 'move-right', => @moveCursorRight()
    @on 'move-left', => @moveCursorLeft()
    @on 'move-down', => @moveCursorDown()
    @on 'move-up', => @moveCursorUp()
    @on 'select-right', => @selectRight()
    @on 'select-left', => @selectLeft()
    @on 'select-up', => @selectUp()
    @on 'select-down', => @selectDown()
    @on 'newline', => @insertText("\n")
    @on 'backspace', => @backspace()
    @on 'delete', => @delete()
    @on 'cut', => @cutSelection()
    @on 'copy', => @copySelection()
    @on 'paste', => @paste()
    @on 'undo', => @undo()
    @on 'redo', => @redo()
    @on 'toggle-soft-wrap', => @toggleSoftWrap()
    @on 'fold-selection', => @foldSelection()
    @on 'split-left', => @splitLeft()
    @on 'split-right', => @splitRight()
    @on 'split-up', => @splitUp()
    @on 'split-down', => @splitDown()
    @on 'close', => @remove(); false

  buildCursorAndSelection: ->
    @compositeSelection = new CompositeSelection(this)
    @compositeCursor = new CompositeCursor(this)

  addCursorAtScreenPosition: (screenPosition) ->
    @compositeCursor.addCursorAtScreenPosition(screenPosition)

  addSelectionForCursor: (cursor) ->
    @compositeSelection.addSelectionForCursor(cursor)

  handleEvents: ->
    @on 'focus', =>
      @hiddenInput.focus()
      false

    @hiddenInput.on 'focus', =>
      @rootView()?.editorFocused(this)
      @isFocused = true
      @addClass 'focused'

    @hiddenInput.on 'focusout', =>
      @isFocused = false
      @removeClass 'focused'

    @on 'mousedown', '.fold-placeholder', (e) =>
      @destroyFold($(e.currentTarget).attr('foldId'))
      false

    @on 'mousedown', (e) =>
      clickCount = e.originalEvent.detail

      if clickCount == 1
        screenPosition = @screenPositionFromMouseEvent(e)
        if e.metaKey
          @addCursorAtScreenPosition(screenPosition)
        else
          @setCursorScreenPosition(screenPosition)
      else if clickCount == 2
        @compositeSelection.lastSelection().selectWord()
      else if clickCount >= 3
        @compositeSelection.lastSelection().selectLine()

      @selectOnMousemoveUntilMouseup()

    @hiddenInput.on "textInput", (e) =>
      @insertText(e.originalEvent.data)

    @horizontalScroller.on 'scroll', =>
      if @horizontalScroller.scrollLeft() == 0
        @gutter.removeClass('drop-shadow')
      else
        @gutter.addClass('drop-shadow')

    @one 'attach', =>
      @calculateDimensions()
      @hiddenInput.width(@charWidth)
      @setMaxLineLength() if @softWrap
      @focus()

  rootView: ->
    @parents('#root-view').view()

  selectOnMousemoveUntilMouseup: ->
    moveHandler = (e) => @selectToScreenPosition(@screenPositionFromMouseEvent(e))
    @on 'mousemove', moveHandler
    $(document).one 'mouseup', =>
      @off 'mousemove', moveHandler
      @compositeSelection.mergeIntersectingSelections()

  renderLines: ->
    @lineCache = []
    @lines.find('.line').remove()
    @insertLineElements(0, @buildLineElements(0, @getLastScreenRow()))

  getScreenLines: ->
    @renderer.getLines()

  linesForRows: (start, end) ->
    @renderer.linesForRows(start, end)

  screenLineCount: ->
    @renderer.lineCount()

  getLastScreenRow: ->
    @screenLineCount() - 1

  setBuffer: (buffer) ->
    if @buffer
      @saveEditSession()
      @unsubscribeFromBuffer()

    @buffer = buffer

    document.title = @buffer.path
    @renderer = new Renderer(@buffer)
    @renderLines()
    @gutter.renderLineNumbers()

    @loadEditSessionForBuffer(@buffer)

    @buffer.on "change.editor#{@id}", (e) => @handleBufferChange(e)
    @renderer.on 'change', (e) => @handleRendererChange(e)

  loadEditSessionForBuffer: (buffer) ->
    @editSession = (@editSessionsByBufferId[buffer.id] ?= new EditSession)
    @setCursorScreenPosition(@editSession.cursorScreenPosition)
    @scrollTop(@editSession.scrollTop)
    @horizontalScroller.scrollLeft(@editSession.scrollLeft)

  saveEditSession: ->
    @editSession.cursorScreenPosition = @getCursorScreenPosition()
    @editSession.scrollTop = @scrollTop()
    @editSession.scrollLeft = @horizontalScroller.scrollLeft()

  handleBufferChange: (e) ->
    @compositeCursor.handleBufferChange(e) if @isFocused

  handleRendererChange: (e) ->
    { oldRange, newRange } = e
    unless newRange.isSingleLine() and newRange.coversSameRows(oldRange)
      @gutter.renderLineNumbers(@getScreenLines())

    @compositeCursor.refreshScreenPosition() unless e.bufferChanged

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

  setMaxLineLength: (maxLineLength) ->
    maxLineLength ?=
      if @softWrap
        Math.floor(@horizontalScroller.width() / @charWidth)
      else
        Infinity

    @renderer.setMaxLineLength(maxLineLength) if maxLineLength

  createFold: (range) ->
    @renderer.createFold(range)

  setSoftWrap: (@softWrap, maxLineLength=undefined) ->
    @setMaxLineLength(maxLineLength)
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

  getCursor: (index) -> @compositeCursor.getCursor(index)
  moveCursorUp: -> @compositeCursor.moveUp()
  moveCursorDown: -> @compositeCursor.moveDown()
  moveCursorRight: -> @compositeCursor.moveRight()
  moveCursorLeft: -> @compositeCursor.moveLeft()

  getCurrentScreenLine: -> @buffer.lineForRow(@getCursorScreenRow())
  getCurrentBufferLine: -> @buffer.lineForRow(@getCursorBufferRow())
  setCursorScreenPosition: (position) -> @compositeCursor.setScreenPosition(position)
  getCursorScreenPosition: -> @getCursor().getScreenPosition()
  setCursorBufferPosition: (position) -> @getCursor().setBufferPosition(position)
  getCursorBufferPosition: -> @getCursor().getBufferPosition()
  setCursorScreenRow: (row) -> @getCursor().setScreenRow(row)
  getCursorScreenRow: -> @getCursor().getScreenRow()
  getCursorBufferRow: -> @getCursor().getBufferPosition().row
  getCursorScreenColumn: -> @getCursor().getScreenColumn()
  setCursorBufferColumn: (column) -> @getCursor().setBufferColumn(column)
  getCursorBufferColumn: -> @getCursor().getBufferColumn()

  getSelection: (index) -> @compositeSelection.getSelection(index)
  getSelectedText: -> @compositeSelection.getSelection().getText()
  selectRight: -> @compositeSelection.getSelection().selectRight()
  selectLeft: -> @compositeSelection.getSelection().selectLeft()
  selectUp: -> @compositeSelection.getSelection().selectUp()
  selectDown: -> @compositeSelection.getSelection().selectDown()
  selectToScreenPosition: (position) -> @compositeSelection.selectToScreenPosition(position)
  selectToBufferPosition: (position) -> @getSelection().selectToBufferPosition(position)

  setText: (text) -> @buffer.setText(text)
  getText: -> @buffer.getText()
  getLastBufferRow: -> @buffer.getLastRow()
  getBufferLineLength: (row) -> @buffer.getLineLength(row)
  getTextInRange: (range) -> @buffer.getTextInRange(range)
  getEofPosition: -> @buffer.getEofPosition()
  lineForBufferRow: (row) -> @buffer.lineForRow(row)

  insertText: (text) ->
    { text, shouldOutdent } = @autoIndentText(text)
    @compositeSelection.insertText(text)
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

  cutSelection: -> @getSelection().cut()
  copySelection: -> @getSelection().copy()
  paste: -> @insertText($native.readFromPasteboard())

  foldSelection: -> @getSelection().fold()

  backspace: ->
    @compositeSelection.backspace()

  delete: ->
    @selectRight() if @getSelection().isEmpty()
    @getSelection().delete()

  undo: ->
    @buffer.undo()

  redo: ->
    @buffer.redo()

  destroyFold: (foldId) ->
    fold = @renderer.foldsById[foldId]
    fold.destroy()
    @setCursorBufferPosition(fold.start)

  logLines: ->
    @renderer.logLines()

  splitLeft: ->
    @split('row', 'before')

  splitRight: ->
    @split('row', 'after')

  splitUp: ->
    @split('column', 'before')

  splitDown: ->
    @split('column', 'after')

  split: (axis, insertMethod) ->
    unless @parent().hasClass axis
      container = $$ -> @div class: axis
      container.insertBefore(this).append(this.detach())

    editor = new Editor({@buffer})
    editor.setCursorScreenPosition(@getCursorScreenPosition())
    this[insertMethod](editor)
    @parents('#root-view').view().adjustSplitPanes()

  remove: (selector, keepData) ->
    return super if keepData
    @unsubscribeFromBuffer()
    rootView = @rootView()
    parent = @parent()
    super
    parent.remove() if parent.is('.row:empty, .column:empty')
    rootView?.editorRemoved(this)

  unsubscribeFromBuffer: ->
    @buffer.off ".editor#{@id}"
    @renderer.destroy()
