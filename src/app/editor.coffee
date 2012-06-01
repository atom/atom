{View, $$} = require 'space-pen'
Buffer = require 'buffer'
CompositeCursor = require 'composite-cursor'
CompositeSelection = require 'composite-selection'
Gutter = require 'gutter'
Renderer = require 'renderer'
Point = require 'point'
Range = require 'range'

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
          @div class: 'lines', outlet: 'visibleLines', =>
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
  highlighter: null
  renderer: null
  autoIndent: null
  lineCache: null
  isFocused: false
  softTabs: true
  tabText: '  '
  editSessions: null
  attached: false
  lineOverdraw: 100

  @deserialize: (viewState, rootView) ->
    viewState = _.clone(viewState)
    viewState.editSessions = viewState.editSessions.map (editSession) ->
      editSession = _.clone(editSession)
      editSession.buffer = Buffer.deserialize(editSession.buffer, rootView.project)
      editSession

    new Editor(viewState)

  initialize: ({editSessions, activeEditSessionIndex, buffer, isFocused, @mini} = {}) ->
    requireStylesheet 'editor.css'
    requireStylesheet 'theme/twilight.css'

    @id = Editor.idCounter++
    @lineCache = []
    @bindKeys()
    @autoIndent = true
    @buildCursorAndSelection()
    @handleEvents()

    @editSessions = editSessions ? []
    if activeEditSessionIndex?
      @loadEditSession(activeEditSessionIndex)
    else if buffer?
      @setBuffer(buffer)
    else
      @setBuffer(new Buffer)

    @isFocused = isFocused if isFocused?

  serialize: ->
    @saveCurrentEditSession()
    { viewClass: "Editor", editSessions: @serializeEditSessions(), @activeEditSessionIndex, @isFocused }

  serializeEditSessions: ->
    @editSessions.map (session) ->
      session = _.clone(session)
      session.buffer = session.buffer.serialize()
      session

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

    for name, method of editorBindings
      do (name, method) =>
        @on name, => method.call(this); false

  buildCursorAndSelection: ->
    @compositeSelection = new CompositeSelection(this)
    @compositeCursor = new CompositeCursor(this)

  addCursorAtScreenPosition: (screenPosition) ->
    @compositeCursor.addCursorAtScreenPosition(screenPosition)

  addCursorAtBufferPosition: (bufferPosition) ->
    @compositeCursor.addCursorAtBufferPosition(bufferPosition)

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

    @visibleLines.on 'mousedown', '.fold.line', (e) =>
      @destroyFold($(e.currentTarget).attr('fold-id'))
      false

    @visibleLines.on 'mousedown', (e) =>
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

    $(window).on "resize.editor#{@id}", =>
      @updateVisibleLines()

  afterAttach: (onDom) ->
    return if @attached or not onDom
    @attached = true
    @clearLines()
    @subscribeToFontSize()
    @calculateDimensions()
    @setMaxLineLength() if @softWrap
    @prepareForVerticalScrolling()

    # this also renders the visible lines
    @setScrollPositionFromActiveEditSession()

    # TODO: The redundant assignment of scrollLeft below is needed because the
    # lines weren't rendered when we called
    # setScrollPositionFromActiveEditSession above. Remove this when we fix that
    # problem by setting the width of the lines container based on the max line
    # length

    @scrollView.scrollLeft(@getActiveEditSession().scrollLeft ? 0)
    @hiddenInput.width(@charWidth)
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

  prepareForVerticalScrolling: ->
    linesHeight = @lineHeight * @screenLineCount()
    @verticalScrollbarContent.height(linesHeight)
    @visibleLines.css('padding-bottom', linesHeight)

  scrollTop: (scrollTop, options) ->
    return @cachedScrollTop or 0 unless scrollTop?

    scrollTop = Math.max(0, scrollTop)
    return if scrollTop == @cachedScrollTop
    @cachedScrollTop = scrollTop

    @updateVisibleLines() if @attached

    @scrollView.scrollTop(scrollTop)
    @gutter.scrollTop(scrollTop)
    if options?.adjustVerticalScrollbar ? true
      @verticalScrollbar.scrollTop(scrollTop)

  scrollBottom: (scrollBottom) ->
    if scrollBottom?
      @scrollTop(scrollBottom - @scrollView.height())
    else
      @scrollTop() + @scrollView.height()

  renderVisibleLines: ->
    @clearLines()
    @updateVisibleLines()

  clearLines: ->
    @lineCache = []
    @visibleLines.find('.line').remove()

    @firstRenderedScreenRow = -1
    @lastRenderedScreenRow = -1

  updateVisibleLines: ->
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
      paddingTop = @firstRenderedScreenRow * @lineHeight
      @visibleLines.css('padding-top', paddingTop)
      @gutter.lineNumbers.css('padding-top', paddingTop)

      paddingBottom = (@getLastScreenRow() - @lastRenderedScreenRow) * @lineHeight
      @visibleLines.css('padding-bottom', paddingBottom)
      @gutter.lineNumbers.css('padding-bottom', paddingBottom)

  getFirstVisibleScreenRow: ->
    Math.floor(@scrollTop() / @lineHeight)

  getLastVisibleScreenRow: ->
    Math.ceil((@scrollTop() + @scrollView.height()) / @lineHeight) - 1

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

  getLastScreenRow: ->
    @screenLineCount() - 1

  isFoldedAtScreenRow: (screenRow) ->
    @screenLineForRow(screenRow).fold?

  destroyFoldsContainingBufferRow: (bufferRow) ->
    @renderer.destroyFoldsContainingBufferRow(bufferRow)

  setBuffer: (buffer) ->
    if @buffer
      @saveCurrentEditSession()
      @unsubscribeFromBuffer()

    @buffer = buffer
    @trigger 'editor-path-change'
    @buffer.on "path-change.editor#{@id}", => @trigger 'editor-path-change'

    @renderer = new Renderer(@buffer, { maxLineLength: @calcMaxLineLength(), tabText: @tabText })
    if @attached
      @prepareForVerticalScrolling()
      @renderVisibleLines()

    @loadEditSessionForBuffer(@buffer)

    @buffer.on "change.editor#{@id}", (e) => @handleBufferChange(e)
    @renderer.on 'change', (e) => @handleRendererChange(e)

  editSessionForBuffer: (buffer) ->
    for editSession, index in @editSessions
      return [editSession, index] if editSession.buffer == buffer
    [undefined, -1]

  loadEditSessionForBuffer: (buffer) ->
    [editSession, index] = @editSessionForBuffer(buffer)
    if editSession
      @activeEditSessionIndex = index
    else
      @editSessions.push({ buffer })
      @activeEditSessionIndex = @editSessions.length - 1
    @loadEditSession()

  loadNextEditSession: ->
    nextIndex = (@activeEditSessionIndex + 1) % @editSessions.length
    @loadEditSession(nextIndex)

  loadPreviousEditSession: ->
    previousIndex = @activeEditSessionIndex - 1
    previousIndex = @editSessions.length - 1 if previousIndex < 0
    @loadEditSession(previousIndex)

  loadEditSession: (index=@activeEditSessionIndex) ->
    editSession = @editSessions[index]
    throw new Error("Edit session not found") unless editSession
    @setBuffer(editSession.buffer) unless @buffer == editSession.buffer
    @activeEditSessionIndex = index
    @setScrollPositionFromActiveEditSession() if @attached
    @setCursorScreenPosition(editSession.cursorScreenPosition ? [0, 0])

  getActiveEditSession: ->
    @editSessions[@activeEditSessionIndex]

  setScrollPositionFromActiveEditSession: ->
    editSession = @getActiveEditSession()
    @scrollTop(editSession.scrollTop ? 0)
    @scrollView.scrollLeft(editSession.scrollLeft ? 0)

  saveCurrentEditSession: ->
    @editSessions[@activeEditSessionIndex] =
      buffer: @buffer
      cursorScreenPosition: @getCursorScreenPosition()
      scrollTop: @scrollTop()
      scrollLeft: @scrollView.scrollLeft()

  handleBufferChange: (e) ->
    @compositeCursor.handleBufferChange(e)
    @compositeSelection.handleBufferChange(e)

  handleRendererChange: (e) ->
    oldScreenRange = e.oldRange
    newScreenRange = e.newRange

    if @attached
      @verticalScrollbarContent.height(@lineHeight * @screenLineCount())

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
      oldScreenRange.start.row = Math.max(oldScreenRange.start.row, @firstRenderedScreenRow)
      newScreenRange.end.row = Math.min(newScreenRange.end.row, maxEndRow)
      oldScreenRange.end.row = Math.min(oldScreenRange.end.row, maxEndRow)

      lineElements = @buildLineElements(newScreenRange.start.row, newScreenRange.end.row)
      @replaceLineElements(oldScreenRange.start.row, oldScreenRange.end.row, lineElements)

      rowDelta = newScreenRange.end.row - oldScreenRange.end.row
      @lastRenderedScreenRow += rowDelta
      @updateVisibleLines() if rowDelta < 0


      if @lastRenderedScreenRow > maxEndRow
        @removeLineElements(maxEndRow + 1, @lastRenderedScreenRow)
        @lastRenderedScreenRow = maxEndRow

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

    lines = @visibleLines[0]
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

  calcMaxLineLength: ->
    if @softWrap
      Math.floor(@scrollView.width() / @charWidth)
    else
      Infinity

  setMaxLineLength: (maxLineLength) ->
    maxLineLength ?= @calcMaxLineLength()
    @renderer.setMaxLineLength(maxLineLength) if maxLineLength

  createFold: (startRow, endRow) ->
    @renderer.createFold(startRow, endRow)

  setSoftWrap: (@softWrap, maxLineLength=undefined) ->
    @setMaxLineLength(maxLineLength) if @attached
    if @softWrap
      @addClass 'soft-wrap'
      @_setMaxLineLength = => @setMaxLineLength()
      $(window).on 'resize', @_setMaxLineLength
    else
      @removeClass 'soft-wrap'
      $(window).off 'resize', @_setMaxLineLength

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
    offset = @visibleLines.offset()
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
    @visibleLines.append(fragment)
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
      @updateVisibleLines()

  getCursors: -> @compositeCursor.getCursors()
  moveCursorUp: -> @compositeCursor.moveUp()
  moveCursorDown: -> @compositeCursor.moveDown()
  moveCursorRight: -> @compositeCursor.moveRight()
  moveCursorLeft: -> @compositeCursor.moveLeft()
  moveCursorToNextWord: -> @compositeCursor.moveToNextWord()
  moveCursorToBeginningOfWord: -> @compositeCursor.moveToBeginningOfWord()
  moveCursorToEndOfWord: -> @compositeCursor.moveToEndOfWord()
  moveCursorToTop: -> @compositeCursor.moveToTop()
  moveCursorToBottom: -> @compositeCursor.moveToBottom()
  moveCursorToBeginningOfLine: -> @compositeCursor.moveToBeginningOfLine()
  moveCursorToFirstCharacterOfLine: -> @compositeCursor.moveToFirstCharacterOfLine()
  moveCursorToEndOfLine: -> @compositeCursor.moveToEndOfLine()
  setCursorScreenPosition: (position) -> @compositeCursor.setScreenPosition(position)
  getCursorScreenPosition: -> @compositeCursor.getCursor().getScreenPosition()
  setCursorBufferPosition: (position) -> @compositeCursor.setBufferPosition(position)
  getCursorBufferPosition: -> @compositeCursor.getCursor().getBufferPosition()

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
    @unsubscribeFromBuffer()
    $(window).off ".editor#{@id}"
    rootView = @rootView()
    rootView?.off ".editor#{@id}"
    if @pane() then @pane().remove() else super
    rootView?.focus()

  unsubscribeFromBuffer: ->
    @buffer.off ".editor#{@id}"
    @renderer.destroy()

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
    @renderer.toggleFoldAtBufferRow(@getCursorBufferPosition().row)

  foldSelection: -> @getSelection().fold()

  unfoldRow: (row) ->
    @renderer.largestFoldForBufferRow(row)?.destroy()

  logLines: (start, end) ->
    @renderer.logLines(start, end)

  logRenderedLines: ->
    @visibleLines.find('.line').each (n) ->
      console.log n, $(this).text()
