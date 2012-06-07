{View, $$} = require 'space-pen'
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

  @content: (params) ->
    @div class: @classes(params), tabindex: -1, =>
      @input class: 'hidden-input', outlet: 'hiddenInput'
      @div class: 'flexbox', =>
        @subview 'gutter', new Gutter
        @div class: 'scroll-view', outlet: 'scrollView', =>
          @div class: 'lines', outlet: 'renderedLines', =>
      @div class: 'vertical-scrollbar', outlet: 'verticalScrollbar', =>
        @div outlet: 'verticalScrollbarContent'

  @classes: ({mini} = {}) ->
    classes = ['editor']
    classes.push 'mini' if mini
    classes.join(' ')

  vScrollMargin: 2
  hScrollMargin: 10
  softWrap: false
  lineHeight: null
  charWidth: null
  charHeight: null
  cursor: null
  selection: null
  buffer: null
  renderer: null
  autoIndent: null
  lineCache: null
  isFocused: false
  softTabs: true
  tabText: '  '
  editSessions: null
  attached: false
  lineOverdraw: 100

  @deserialize: (state, rootView) ->
    editor = new Editor(suppressBufferCreation: true, mini: state.mini)
    editor.editSessions = state.editSessions.map (state) -> EditSession.deserialize(state, editor, rootView)
    editor.setActiveEditSessionIndex(state.activeEditSessionIndex)
    editor.isFocused = state.isFocused
    editor

  initialize: ({buffer, suppressBufferCreation, @mini} = {}) ->
    requireStylesheet 'editor.css'
    requireStylesheet 'theme/twilight.css'

    @id = Editor.idCounter++
    @lineCache = []
    @bindKeys()
    @autoIndent = true
    @buildCursorAndSelection()
    @handleEvents()
    @editSessions = []

    if buffer?
      @setBuffer(buffer)
    else if !suppressBufferCreation
      @setBuffer(new Buffer)

  serialize: ->
    @saveActiveEditSession()
    { viewClass: "Editor", editSessions: @serializeEditSessions(), @activeEditSessionIndex, @isFocused }

  serializeEditSessions: ->
    @editSessions.map (session) -> session.serialize()

  copy: ->
    Editor.deserialize(@serialize(), @rootView())

  bindKeys: ->
    editorBindings =
      'save': @save
      'move-right': @moveCursorRight
      'move-left': @moveCursorLeft
      'move-down': @moveCursorDown
      'move-up': @moveCursorUp
      'move-to-next-word': @moveCursorToNextWord
      'move-to-previous-word': @moveCursorToPreviousWord
      'select-right': @selectRight
      'select-left': @selectLeft
      'select-up': @selectUp
      'select-down': @selectDown
      'newline': @insertNewline
      'newline-below': @insertNewlineBelow
      'tab': @insertTab
      'indent-selected-rows': @indentSelectedRows
      'outdent-selected-rows': @outdentSelectedRows
      'backspace': @backspace
      'backspace-to-beginning-of-word': @backspaceToBeginningOfWord
      'delete': @delete
      'delete-to-end-of-word': @deleteToEndOfWord
      'cut-to-end-of-line': @cutToEndOfLine
      'cut': @cutSelection
      'copy': @copySelection
      'paste': @paste
      'undo': @undo
      'redo': @redo
      'toggle-soft-wrap': @toggleSoftWrap
      'fold-all': @foldAll
      'toggle-fold': @toggleFold
      'fold-selection': @foldSelection
      'unfold': => @unfoldRow(@getCursorBufferPosition().row)
      'split-left': @splitLeft
      'split-right': @splitRight
      'split-up': @splitUp
      'split-down': @splitDown
      'close': @close
      'show-next-buffer': @loadNextEditSession
      'show-previous-buffer': @loadPreviousEditSession

      'move-to-top': @moveCursorToTop
      'move-to-bottom': @moveCursorToBottom
      'move-to-beginning-of-line': @moveCursorToBeginningOfLine
      'move-to-end-of-line': @moveCursorToEndOfLine
      'move-to-first-character-of-line': @moveCursorToFirstCharacterOfLine
      'move-to-beginning-of-word': @moveCursorToBeginningOfWord
      'move-to-end-of-word': @moveCursorToEndOfWord
      'select-to-top': @selectToTop
      'select-to-bottom': @selectToBottom
      'select-to-end-of-line': @selectToEndOfLine
      'select-to-beginning-of-line': @selectToBeginningOfLine
      'select-to-end-of-word': @selectToEndOfWord
      'select-to-beginning-of-word': @selectToBeginningOfWord
      'select-all': @selectAll
      'toggle-line-comments': @toggleLineCommentsInSelection

    for name, method of editorBindings
      do (name, method) =>
        @on name, => method.call(this); false

  buildCursorAndSelection: ->
    @compositeSelection = new CompositeSelection(this)
    @compositeCursor = new CompositeCursor(this)

  addCursor: ->
    @activeEditSession.addCursorAtScreenPosition([0, 0])

  addCursorAtScreenPosition: (screenPosition) ->
    @activeEditSession.addCursorAtScreenPosition(screenPosition)

  addCursorAtBufferPosition: (bufferPosition) ->
    @activeEditSession.addCursorAtBufferPosition(bufferPosition)

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

    @renderedLines.on 'mousedown', '.fold.line', (e) =>
      @destroyFold($(e.currentTarget).attr('fold-id'))
      false

    @renderedLines.on 'mousedown', (e) =>
      clickCount = e.originalEvent.detail

      if clickCount == 1
        screenPosition = @screenPositionFromMouseEvent(e)
        if e.metaKey
          @addCursorAtScreenPosition(screenPosition)
        else if e.shiftKey
          @selectToScreenPosition(@screenPositionFromMouseEvent(e))
        else
          @setCursorScreenPosition(screenPosition)
      else if clickCount == 2
        if e.shiftKey
          @compositeSelection.getLastSelection().expandOverWord()
        else
          @compositeSelection.getLastSelection().selectWord()
      else if clickCount >= 3
        if e.shiftKey
          @compositeSelection.getLastSelection().expandOverLine()
        else
          @compositeSelection.getLastSelection().selectLine()

      @selectOnMousemoveUntilMouseup()

    @on "textInput", (e) =>
      @insertText(e.originalEvent.data)
      false

    @scrollView.on 'mousewheel', (e) =>
      e = e.originalEvent
      if e.wheelDeltaY
        newEvent = document.createEvent("WheelEvent");
        newEvent.initWebKitWheelEvent(0, e.wheelDeltaY, e.view, e.screenX, e.screenY, e.clientX, e.clientY, e.ctrlKey, e.altKey, e.shiftKey, e.metaKey)
        @verticalScrollbar.get(0).dispatchEvent(newEvent)
        false

    @verticalScrollbar.on 'scroll', =>
      @scrollTop(@verticalScrollbar.scrollTop(), adjustVerticalScrollbar: false)

    @scrollView.on 'scroll', =>
      if @scrollView.scrollLeft() == 0
        @gutter.removeClass('drop-shadow')
      else
        @gutter.addClass('drop-shadow')


  afterAttach: (onDom) ->
    return if @attached or not onDom
    @attached = true
    @clearRenderedLines()
    @subscribeToFontSize()
    @calculateDimensions()
    @hiddenInput.width(@charWidth)
    @setSoftWrapColumn() if @softWrap
    @prepareForScrolling()
    @setScrollPositionFromActiveEditSession() # this also renders the visible lines
    $(window).on "resize.editor#{@id}", => @updateRenderedLines()
    @focus() if @isFocused
    @trigger 'editor-open', [this]

  rootView: ->
    @parents('#root-view').view()

  selectOnMousemoveUntilMouseup: ->
    moveHandler = (e) => @selectToScreenPosition(@screenPositionFromMouseEvent(e))
    @on 'mousemove', moveHandler
    $(document).one 'mouseup', =>
      @off 'mousemove', moveHandler
      reverse = @compositeSelection.getLastSelection().isReversed()
      @compositeSelection.mergeIntersectingSelections({reverse})
      @syncCursorAnimations()

  prepareForScrolling: ->
    @adjustHeightOfRenderedLines()
    @adjustWidthOfRenderedLines()

  adjustHeightOfRenderedLines: ->
    heightOfRenderedLines = @lineHeight * @screenLineCount()
    @verticalScrollbarContent.height(heightOfRenderedLines)
    @renderedLines.css('padding-bottom', heightOfRenderedLines)

  adjustWidthOfRenderedLines: ->
    @renderedLines.width(@charWidth * @maxScreenLineLength())

  scrollTop: (scrollTop, options) ->
    return @cachedScrollTop or 0 unless scrollTop?

    maxScrollTop = @scrollView.prop('scrollHeight') - @scrollView.height()
    scrollTop = Math.floor(Math.min(maxScrollTop, Math.max(0, scrollTop)))

    return if scrollTop == @cachedScrollTop
    @cachedScrollTop = scrollTop

    @updateRenderedLines() if @attached

    @scrollView.scrollTop(scrollTop)
    @gutter.scrollTop(scrollTop)
    if options?.adjustVerticalScrollbar ? true
      @verticalScrollbar.scrollTop(scrollTop)

  scrollBottom: (scrollBottom) ->
    if scrollBottom?
      @scrollTop(scrollBottom - @scrollView.height())
    else
      @scrollTop() + @scrollView.height()

  highlightSelectedFolds: ->
    screenLines = @screenLinesForRows(@firstRenderedScreenRow, @lastRenderedScreenRow)
    for screenLine, i in screenLines
      if fold = screenLine.fold
        screenRow = @firstRenderedScreenRow + i
        element = @lineElementForScreenRow(screenRow)
        if @compositeSelection.intersectsBufferRange(fold.getBufferRange())
          element.addClass('selected')
        else
          element.removeClass('selected')

  getScreenLines: ->
    @renderer.getLines()

  screenLineForRow: (start) ->
    @renderer.lineForRow(start)

  screenLinesForRows: (start, end) ->
    @renderer.linesForRows(start, end)

  screenLineCount: ->
    @renderer.lineCount()

  maxScreenLineLength: ->
    @renderer.maxLineLength()

  getLastScreenRow: ->
    @screenLineCount() - 1

  isFoldedAtScreenRow: (screenRow) ->
    @screenLineForRow(screenRow).fold?

  destroyFoldsContainingBufferRow: (bufferRow) ->
    @renderer.destroyFoldsContainingBufferRow(bufferRow)

  setBuffer: (buffer) ->
    @activateEditSessionForBuffer(buffer)

  setRenderer: (renderer) ->
    @renderer?.off()
    @renderer = renderer
    @renderer.on 'change', (e) => @handleRendererChange(e)

    @unsubscribeFromBuffer() if @buffer
    @buffer = renderer.buffer
    @buffer.on "path-change.editor#{@id}", => @trigger 'editor-path-change'
    @buffer.on "change.editor#{@id}", (e) => @handleBufferChange(e)
    @trigger 'editor-path-change'

  activateEditSessionForBuffer: (buffer) ->
    index = @editSessionIndexForBuffer(buffer)
    unless index?
      index = @editSessions.length
      @editSessions.push(new EditSession(this, buffer))

    @setActiveEditSessionIndex(index)

  editSessionIndexForBuffer: (buffer) ->
    for editSession, index in @editSessions
      return index if editSession.buffer == buffer
    null

  loadNextEditSession: ->
    nextIndex = (@activeEditSessionIndex + 1) % @editSessions.length
    @setActiveEditSessionIndex(nextIndex)

  loadPreviousEditSession: ->
    previousIndex = @activeEditSessionIndex - 1
    previousIndex = @editSessions.length - 1 if previousIndex < 0
    @setActiveEditSessionIndex(previousIndex)

  setActiveEditSessionIndex: (index) ->
    throw new Error("Edit session not found") unless @editSessions[index]

    if @activeEditSession
      @saveActiveEditSession()
      @compositeCursor.removeAllCursors()
      @activeEditSession.off()

    @activeEditSession = @editSessions[index]
    @activeEditSessionIndex = index

    @setRenderer(@activeEditSession.getRenderer())
    if @attached
      @prepareForScrolling()
      @setScrollPositionFromActiveEditSession()
      @renderLines()

    for cursor in @activeEditSession.getCursors()
      @compositeCursor.addCursorView(cursor)

    @activeEditSession.on 'add-cursor', (cursor) =>
      @compositeCursor.addCursorView(cursor)

  setScrollPositionFromActiveEditSession: ->
    @scrollTop(@activeEditSession.scrollTop ? 0)
    @scrollView.scrollLeft(@activeEditSession.scrollLeft ? 0)

  saveActiveEditSession: ->
    @activeEditSession.setCursorScreenPosition(@getCursorScreenPosition())
    @activeEditSession.setScrollTop(@scrollTop())
    @activeEditSession.setScrollLeft(@scrollView.scrollLeft())

  renderLines: ->
    @clearRenderedLines()
    @updateRenderedLines()

  clearRenderedLines: ->
    @lineCache = []
    @renderedLines.find('.line').remove()

    @firstRenderedScreenRow = -1
    @lastRenderedScreenRow = -1

  updateRenderedLines: ->
    firstVisibleScreenRow = @getFirstVisibleScreenRow()
    lastVisibleScreenRow = @getLastVisibleScreenRow()
    renderFrom = Math.max(0, firstVisibleScreenRow - @lineOverdraw)
    renderTo = Math.min(@getLastScreenRow(), lastVisibleScreenRow + @lineOverdraw)

    if firstVisibleScreenRow < @firstRenderedScreenRow
      @removeLineElements(Math.max(@firstRenderedScreenRow, renderTo + 1), @lastRenderedScreenRow)
      @lastRenderedScreenRow = renderTo
      newLines = @buildLineElements(renderFrom, Math.min(@firstRenderedScreenRow - 1, renderTo))
      @insertLineElements(renderFrom, newLines)
      @firstRenderedScreenRow = renderFrom
      renderedLines = true

    if lastVisibleScreenRow > @lastRenderedScreenRow
      if 0 <= @firstRenderedScreenRow < renderFrom
        @removeLineElements(@firstRenderedScreenRow, Math.min(@lastRenderedScreenRow, renderFrom - 1))
      @firstRenderedScreenRow = renderFrom
      startRowOfNewLines = Math.max(@lastRenderedScreenRow + 1, renderFrom)
      newLines = @buildLineElements(startRowOfNewLines, renderTo)
      @insertLineElements(startRowOfNewLines, newLines)
      @lastRenderedScreenRow = renderTo
      renderedLines = true

    if renderedLines
      @gutter.renderLineNumbers(renderFrom, renderTo)
      @updatePaddingOfRenderedLines()

  updatePaddingOfRenderedLines: ->
    paddingTop = @firstRenderedScreenRow * @lineHeight
    @renderedLines.css('padding-top', paddingTop)
    @gutter.lineNumbers.css('padding-top', paddingTop)

    paddingBottom = (@getLastScreenRow() - @lastRenderedScreenRow) * @lineHeight
    @renderedLines.css('padding-bottom', paddingBottom)
    @gutter.lineNumbers.css('padding-bottom', paddingBottom)

  getFirstVisibleScreenRow: ->
    Math.floor(@scrollTop() / @lineHeight)

  getLastVisibleScreenRow: ->
    Math.ceil((@scrollTop() + @scrollView.height()) / @lineHeight) - 1

  handleBufferChange: (e) ->
    @compositeCursor.handleBufferChange(e)
    @compositeSelection.handleBufferChange(e)

  handleRendererChange: (e) ->
    oldScreenRange = e.oldRange
    newScreenRange = e.newRange

    if @attached
      @verticalScrollbarContent.height(@lineHeight * @screenLineCount())
      @adjustWidthOfRenderedLines()

      return if oldScreenRange.start.row > @lastRenderedScreenRow

      maxEndRow = Math.max(@getLastVisibleScreenRow() + @lineOverdraw, @lastRenderedScreenRow)
      @gutter.renderLineNumbers(@firstRenderedScreenRow, maxEndRow) if e.lineNumbersChanged

      newScreenRange = newScreenRange.copy()
      oldScreenRange = oldScreenRange.copy()
      endOfShortestRange = Math.min(oldScreenRange.end.row, newScreenRange.end.row)

      delta = @firstRenderedScreenRow - endOfShortestRange
      if delta > 0
        newScreenRange.start.row += delta
        newScreenRange.end.row += delta
        oldScreenRange.start.row += delta
        oldScreenRange.end.row += delta

      newScreenRange.start.row = Math.max(newScreenRange.start.row, @firstRenderedScreenRow)
      oldScreenRange.end.row = Math.min(oldScreenRange.end.row, @lastRenderedScreenRow)
      oldScreenRange.start.row = Math.max(oldScreenRange.start.row, @firstRenderedScreenRow)
      newScreenRange.end.row = Math.min(newScreenRange.end.row, maxEndRow)

      lineElements = @buildLineElements(newScreenRange.start.row, newScreenRange.end.row)
      @replaceLineElements(oldScreenRange.start.row, oldScreenRange.end.row, lineElements)

      rowDelta = newScreenRange.end.row - oldScreenRange.end.row
      @lastRenderedScreenRow += rowDelta
      @updateRenderedLines() if rowDelta < 0

      if @lastRenderedScreenRow > maxEndRow
        @removeLineElements(maxEndRow + 1, @lastRenderedScreenRow)
        @lastRenderedScreenRow = maxEndRow
        @updatePaddingOfRenderedLines()

    @compositeCursor.updateBufferPosition() unless e.bufferChanged

  buildLineElements: (startRow, endRow) ->
    charWidth = @charWidth
    charHeight = @charHeight
    lines = @renderer.linesForRows(startRow, endRow)
    compositeSelection = @compositeSelection

    $$ ->
      for line in lines
        if fold = line.fold
          lineAttributes = { class: 'fold line', 'fold-id': fold.id }
          if compositeSelection.intersectsBufferRange(fold.getBufferRange())
            lineAttributes.class += ' selected'
        else
          lineAttributes = { class: 'line' }
        @div lineAttributes, =>
          if line.text == ''
            @raw '&nbsp;' if line.text == ''
          else
            for token in line.tokens
              @span { class: token.type.replace('.', ' ') }, token.value

  insertLineElements: (row, lineElements) ->
    @spliceLineElements(row, 0, lineElements)

  replaceLineElements: (startRow, endRow, lineElements) ->
    @spliceLineElements(startRow, endRow - startRow + 1, lineElements)

  removeLineElements: (startRow, endRow) ->
    @spliceLineElements(startRow, endRow - startRow + 1)

  spliceLineElements: (startScreenRow, rowCount, lineElements) ->
    throw new Error("Splicing at a negative start row: #{startScreenRow}") if startScreenRow < 0

    if startScreenRow < @firstRenderedScreenRow
      startRow = 0
    else
      startRow = startScreenRow - @firstRenderedScreenRow

    endRow = startRow + rowCount

    elementToInsertBefore = @lineCache[startRow]
    elementsToReplace = @lineCache[startRow...endRow]
    @lineCache[startRow...endRow] = lineElements?.toArray() or []

    lines = @renderedLines[0]
    if lineElements
      fragment = document.createDocumentFragment()
      lineElements.each -> fragment.appendChild(this)
      if elementToInsertBefore
        lines.insertBefore(fragment, elementToInsertBefore)
      else
        lines.appendChild(fragment)

    elementsToReplace.forEach (element) =>
      lines.removeChild(element)

  lineElementForScreenRow: (screenRow) ->
    element = @lineCache[screenRow - @firstRenderedScreenRow]
    $(element)

  toggleSoftWrap: ->
    @setSoftWrap(not @softWrap)

  calcSoftWrapColumn: ->
    if @softWrap
      Math.floor(@scrollView.width() / @charWidth)
    else
      Infinity

  setSoftWrapColumn: (softWrapColumn) ->
    softWrapColumn ?= @calcSoftWrapColumn()
    @renderer.setSoftWrapColumn(softWrapColumn) if softWrapColumn

  createFold: (startRow, endRow) ->
    @renderer.createFold(startRow, endRow)

  setSoftWrap: (@softWrap, softWrapColumn=undefined) ->
    @setSoftWrapColumn(softWrapColumn) if @attached
    if @softWrap
      @addClass 'soft-wrap'
      @_setSoftWrapColumn = => @setSoftWrapColumn()
      $(window).on 'resize', @_setSoftWrapColumn
    else
      @removeClass 'soft-wrap'
      $(window).off 'resize', @_setSoftWrapColumn

  save: ->
    if not @buffer.getPath()
      path = $native.saveDialog()
      return if not path
      @buffer.saveAs(path)
    else
      @buffer.save()

  clipScreenPosition: (screenPosition, options={}) ->
    @renderer.clipScreenPosition(screenPosition, options)

  pixelPositionForScreenPosition: (position) ->
    position = Point.fromObject(position)
    { top: position.row * @lineHeight, left: position.column * @charWidth }

  pixelOffsetForScreenPosition: (position) ->
    {top, left} = @pixelPositionForScreenPosition(position)
    offset = @renderedLines.offset()
    {top: top + offset.top, left: left + offset.left}

  screenPositionFromPixelPosition: ({top, left}) ->
    screenPosition = new Point(Math.floor(top / @lineHeight), Math.floor(left / @charWidth))

  screenPositionForBufferPosition: (position, options) ->
    @renderer.screenPositionForBufferPosition(position, options)

  bufferPositionForScreenPosition: (position, options) ->
    @renderer.bufferPositionForScreenPosition(position, options)

  screenRangeForBufferRange: (range) ->
    @renderer.screenRangeForBufferRange(range)

  bufferRangeForScreenRange: (range) ->
    @renderer.bufferRangeForScreenRange(range)

  bufferRowsForScreenRows: (startRow, endRow) ->
    @renderer.bufferRowsForScreenRows(startRow, endRow)

  screenPositionFromMouseEvent: (e) ->
    { pageX, pageY } = e
    @screenPositionFromPixelPosition
      top: pageY - @scrollView.offset().top + @scrollTop()
      left: pageX - @scrollView.offset().left + @scrollView.scrollLeft()

  calculateDimensions: ->
    fragment = $('<div class="line" style="position: absolute; visibility: hidden;"><span>x</span></div>')
    @renderedLines.append(fragment)
    @charWidth = fragment.width()
    @charHeight = fragment.find('span').height()
    @lineHeight = fragment.outerHeight()
    @height(@lineHeight) if @mini
    fragment.remove()

  subscribeToFontSize: ->
    return unless rootView = @rootView()
    @setFontSize(rootView.getFontSize())
    rootView.on "font-size-change.editor#{@id}", => @setFontSize(rootView.getFontSize())

  setFontSize: (fontSize) ->
    if fontSize
      @css('font-size', fontSize + 'px')
      @calculateDimensions()
      @compositeCursor.updateAppearance()
      @updateRenderedLines()

  getCursors: -> @compositeCursor.getCursors()
  moveCursorUp: -> @activeEditSession.moveCursorUp()
  moveCursorDown: -> @activeEditSession.moveCursorDown()
  moveCursorLeft: -> @activeEditSession.moveCursorLeft()
  moveCursorRight: -> @activeEditSession.moveCursorRight()
  moveCursorToNextWord: -> @compositeCursor.moveToNextWord()
  moveCursorToBeginningOfWord: -> @compositeCursor.moveToBeginningOfWord()
  moveCursorToEndOfWord: -> @compositeCursor.moveToEndOfWord()
  moveCursorToTop: -> @activeEditSession.moveCursorToTop()
  moveCursorToBottom: -> @activeEditSession.moveCursorToBottom()
  moveCursorToBeginningOfLine: -> @activeEditSession.moveCursorToBeginningOfLine()
  moveCursorToFirstCharacterOfLine: -> @activeEditSession.moveCursorToFirstCharacterOfLine()
  moveCursorToEndOfLine: -> @activeEditSession.moveCursorToEndOfLine()
  setCursorScreenPosition: (position) -> @activeEditSession.setCursorScreenPosition(position)
  getCursorScreenPosition: -> @activeEditSession.getCursorScreenPosition()
  setCursorBufferPosition: (position) -> @activeEditSession.setCursorBufferPosition(position)
  getCursorBufferPosition: -> @activeEditSession.getCursorBufferPosition()

  getSelection: (index) -> @compositeSelection.getSelection(index)
  getSelections: -> @compositeSelection.getSelections()
  getSelectionsOrderedByBufferPosition: -> @compositeSelection.getSelectionsOrderedByBufferPosition()
  getLastSelectionInBuffer: -> @compositeSelection.getLastSelectionInBuffer()
  getSelectedText: -> @compositeSelection.getSelection().getText()
  setSelectionBufferRange: (bufferRange, options) -> @compositeSelection.setBufferRange(bufferRange, options)
  setSelectedBufferRanges: (bufferRanges) -> @compositeSelection.setBufferRanges(bufferRanges)
  addSelectionForBufferRange: (bufferRange, options) -> @compositeSelection.addSelectionForBufferRange(bufferRange, options)
  selectRight: -> @compositeSelection.selectRight()
  selectLeft: -> @compositeSelection.selectLeft()
  selectUp: -> @compositeSelection.selectUp()
  selectDown: -> @compositeSelection.selectDown()
  selectToTop: -> @compositeSelection.selectToTop()
  selectToBottom: -> @compositeSelection.selectToBottom()
  selectAll: -> @compositeSelection.selectAll()
  selectToBeginningOfLine: -> @compositeSelection.selectToBeginningOfLine()
  selectToEndOfLine: -> @compositeSelection.selectToEndOfLine()
  selectToBeginningOfWord: -> @compositeSelection.selectToBeginningOfWord()
  selectToEndOfWord: -> @compositeSelection.selectToEndOfWord()
  selectToScreenPosition: (position) -> @compositeSelection.selectToScreenPosition(position)
  clearSelections: -> @compositeSelection.clearSelections()
  backspace: -> @compositeSelection.backspace()
  backspaceToBeginningOfWord: -> @compositeSelection.backspaceToBeginningOfWord()
  delete: -> @compositeSelection.delete()
  deleteToEndOfWord: -> @compositeSelection.deleteToEndOfWord()
  cutToEndOfLine: -> @compositeSelection.cutToEndOfLine()

  setText: (text) -> @buffer.setText(text)
  getText: -> @buffer.getText()
  getLastBufferRow: -> @buffer.getLastRow()
  getTextInRange: (range) -> @buffer.getTextInRange(range)
  getEofPosition: -> @buffer.getEofPosition()
  lineForBufferRow: (row) -> @buffer.lineForRow(row)
  lineLengthForBufferRow: (row) -> @buffer.lineLengthForRow(row)
  rangeForBufferRow: (row) -> @buffer.rangeForRow(row)
  scanInRange: (args...) -> @buffer.scanInRange(args...)
  backwardsScanInRange: (args...) -> @buffer.backwardsScanInRange(args...)

  insertText: (text) ->
    @compositeSelection.insertText(text)

  insertNewline: ->
    @insertText('\n')

  insertNewlineBelow: ->
    @moveCursorToEndOfLine()
    @insertNewline()

  insertTab: ->
    if @getSelection().isEmpty()
      if @softTabs
        @compositeSelection.insertText(@tabText)
      else
        @compositeSelection.insertText('\t')
    else
      @compositeSelection.indentSelectedRows()

  indentSelectedRows: -> @compositeSelection.indentSelectedRows()
  outdentSelectedRows: -> @compositeSelection.outdentSelectedRows()

  cutSelection: -> @compositeSelection.cut()
  copySelection: -> @compositeSelection.copy()
  paste: -> @insertText($native.readFromPasteboard())

  undo: ->
    if ranges = @buffer.undo()
      @setSelectedBufferRanges(ranges)

  redo: ->
    if ranges = @buffer.redo()
      @setSelectedBufferRanges(ranges)

  destroyFold: (foldId) ->
    fold = @renderer.foldsById[foldId]
    fold.destroy()
    @setCursorBufferPosition([fold.startRow, 0])

  splitLeft: ->
    @pane()?.splitLeft(@copy()).wrappedView

  splitRight: ->
    @pane()?.splitRight(@copy()).wrappedView

  splitUp: ->
    @pane()?.splitUp(@copy()).wrappedView

  splitDown: ->
    @pane()?.splitDown(@copy()).wrappedView

  pane: ->
    @parent('.pane').view()

  close: ->
    @remove() unless @mini

  remove: (selector, keepData) ->
    return super if keepData

    @trigger 'before-remove'

    @destroyEditSessions()
    @unsubscribeFromBuffer()

    $(window).off ".editor#{@id}"
    rootView = @rootView()
    rootView?.off ".editor#{@id}"
    if @pane() then @pane().remove() else super
    rootView?.focus()

  unsubscribeFromBuffer: ->
    @buffer.off ".editor#{@id}"

  destroyEditSessions: ->
    session.destroy() for session in @editSessions

  stateForScreenRow: (row) ->
    @renderer.lineForRow(row).state

  getCurrentMode: ->
    @buffer.getMode()

  scrollTo: (pixelPosition) ->
    return unless @attached
    @scrollVertically(pixelPosition)
    @scrollHorizontally(pixelPosition)

  scrollToBottom: ->
    @scrollBottom(@scrollView.prop('scrollHeight'))

  scrollVertically: (pixelPosition) ->
    linesInView = @scrollView.height() / @lineHeight
    maxScrollMargin = Math.floor((linesInView - 1) / 2)
    scrollMargin = Math.min(@vScrollMargin, maxScrollMargin)
    margin = scrollMargin * @lineHeight
    desiredTop = pixelPosition.top - margin
    desiredBottom = pixelPosition.top + @lineHeight + margin

    scrollViewHeight = @scrollView.height()
    if desiredBottom > @scrollTop() + scrollViewHeight
      @scrollTop(desiredBottom - scrollViewHeight)
    else if desiredTop < @scrollTop()
      @scrollTop(desiredTop)

  scrollHorizontally: (pixelPosition) ->
    return if @softWrap

    charsInView = @scrollView.width() / @charWidth
    maxScrollMargin = Math.floor((charsInView - 1) / 2)
    scrollMargin = Math.min(@hScrollMargin, maxScrollMargin)
    margin = scrollMargin * @charWidth
    desiredRight = pixelPosition.left + @charWidth + margin
    desiredLeft = pixelPosition.left - margin

    if desiredRight > @scrollView.scrollRight()
      @scrollView.scrollRight(desiredRight)
    else if desiredLeft < @scrollView.scrollLeft()
      @scrollView.scrollLeft(desiredLeft)

  syncCursorAnimations: ->
    for cursor in @getCursors()
      do (cursor) -> cursor.resetCursorAnimation()

  foldAll: ->
    @renderer.foldAll()

  toggleFold: ->
    row = @renderer.bufferPositionForScreenPosition(@getCursorScreenPosition()).row
    @renderer.toggleFoldAtBufferRow(row)

  foldSelection: -> @getSelection().fold()

  unfoldRow: (row) ->
    @renderer.largestFoldForBufferRow(row)?.destroy()

  logLines: (start, end) ->
    @renderer.logLines(start, end)

  toggleLineCommentsInSelection: ->
    @compositeSelection.toggleLineComments()

  toggleLineCommentsInRange: (range) ->
    @renderer.toggleLineCommentsInRange(range)

  logRenderedLines: ->
    @renderedLines.find('.line').each (n) ->
      console.log n, $(this).text()
