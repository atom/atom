{View, $$} = require 'space-pen'
Buffer = require 'buffer'
Gutter = require 'gutter'
Renderer = require 'renderer'
Point = require 'point'
Range = require 'range'
EditSession = require 'edit-session'
CursorView = require 'cursor-view'
SelectionView = require 'selection-view'
Native = require 'native'
fs = require 'fs'

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
  cursorViews: null
  selectionViews: null
  buffer: null
  renderer: null
  autoIndent: true
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
    @handleEvents()
    @cursorViews = []
    @selectionViews = []
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

  addCursor: ->
    @activeEditSession.addCursorAtScreenPosition([0, 0])

  addCursorAtScreenPosition: (screenPosition) ->
    @activeEditSession.addCursorAtScreenPosition(screenPosition)

  addCursorAtBufferPosition: (bufferPosition) ->
    @activeEditSession.addCursorAtBufferPosition(bufferPosition)

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

      screenPosition = @screenPositionFromMouseEvent(e)
      if clickCount == 1
        if e.metaKey
          @addCursorAtScreenPosition(screenPosition)
        else if e.shiftKey
          @selectToScreenPosition(screenPosition)
        else
          @setCursorScreenPosition(screenPosition)
      else if clickCount == 2
        if e.shiftKey
          @activeEditSession.expandLastSelectionOverWord()
        else
          @activeEditSession.selectWord()
      else if clickCount >= 3
        if e.shiftKey
          @activeEditSession.expandLastSelectionOverLine()
        else
          @activeEditSession.selectLine()

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
    $(window).on "resize.editor#{@id}", => @updateRenderedLines()
    @focus() if @isFocused

    @renderWhenAttached()

    @trigger 'editor-open', [this]

  addCursorView: (cursor) ->
    cursorView = new CursorView(cursor, this)
    @cursorViews.push(cursorView)
    @renderedLines.append(cursorView)
    cursorView

  removeCursorView: (cursorView) ->
    _.remove(@cursorViews, cursorView)

  updateCursorViews: ->
    for cursorView in @getCursorViews()
      cursorView.updateAppearance()

  addSelectionView: (selection) ->
    selectionView = new SelectionView({editor: this, selection})
    @selectionViews.push(selectionView)
    @renderedLines.append(selectionView)
    selectionView

  selectionViewForCursor: (cursor) ->
    for selectionView in @selectionViews
      return selectionView if selectionView.selection.cursor == cursor

  removeSelectionView: (selectionView) ->
    _.remove(@selectionViews, selectionView)

  rootView: ->
    @parents('#root-view').view()

  selectOnMousemoveUntilMouseup: ->
    moveHandler = (e) => @selectToScreenPosition(@screenPositionFromMouseEvent(e))
    @on 'mousemove', moveHandler
    $(document).one 'mouseup', =>
      @off 'mousemove', moveHandler
      reverse = @activeEditSession.getLastSelection().isReversed()
      @activeEditSession.mergeIntersectingSelections({reverse})
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

    maxScrollTop = @verticalScrollbar.prop('scrollHeight') - @verticalScrollbar.height()
    scrollTop = Math.floor(Math.min(maxScrollTop, Math.max(0, scrollTop)))

    return if scrollTop == @cachedScrollTop
    @cachedScrollTop = scrollTop

    @updateRenderedLines() if @attached

    @renderedLines.css('top', -scrollTop)
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
        if @activeEditSession.selectionIntersectsBufferRange(fold.getBufferRange())
          element.addClass('selected')
        else
          element.removeClass('selected')

  setAutoIndent: (@autoIndent) ->
    @activeEditSession.setAutoIndent(@autoIndent)

  setSoftTabs: (@softTabs) ->
    @activeEditSession.setSoftTabs(@softTabs)

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
    @activeEditSession.isFoldedAtScreenRow(screenRow)

  destroyFoldsContainingBufferRow: (bufferRow) ->
    @renderer.destroyFoldsContainingBufferRow(bufferRow)

  setBuffer: (buffer) ->
    @activateEditSessionForBuffer(buffer)

  activateEditSessionForBuffer: (buffer) ->
    index = @editSessionIndexForBuffer(buffer)
    unless index?
      index = @editSessions.length
      @editSessions.push(new EditSession(editor: this, buffer: buffer, autoIndent: @autoIndent, softTabs: @softTabs))

    @setActiveEditSessionIndex(index)

  editSessionIndexForBuffer: (buffer) ->
    for editSession, index in @editSessions
      return index if editSession.buffer == buffer
    null

  removeActiveEditSession: ->
    if @editSessions.length == 1
      @remove()
    else
      editSession = @activeEditSession
      @loadPreviousEditSession()
      _.remove(@editSessions, editSession)

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
      @activeEditSession.off()

    @activeEditSession = @editSessions[index]
    @activeEditSessionIndex = index

    @unsubscribeFromBuffer() if @buffer
    @buffer = @activeEditSession.buffer
    @buffer.on "path-change.editor#{@id}", => @trigger 'editor-path-change'
    @trigger 'editor-path-change'

    @renderer = @activeEditSession.renderer
    @renderWhenAttached()

  renderWhenAttached: ->
    return unless @attached

    @removeAllCursorAndSelectionViews()
    @addCursorView(cursor) for cursor in @activeEditSession.getCursors()
    @addSelectionView(selection) for selection in @activeEditSession.getSelections()
    @activeEditSession.on 'add-cursor', (cursor) => @addCursorView(cursor)
    @activeEditSession.on 'add-selection', (selection) => @addSelectionView(selection)

    @prepareForScrolling()
    @setScrollPositionFromActiveEditSession()

    @renderLines()
    @activeEditSession.on 'screen-lines-change', (e) => @handleRendererChange(e)

  destroyEditSessions: ->
    session.destroy() for session in @editSessions

  setScrollPositionFromActiveEditSession: ->
    @scrollTop(@activeEditSession.scrollTop ? 0)
    @scrollView.scrollLeft(@activeEditSession.scrollLeft ? 0)

  saveActiveEditSession: ->
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

  buildLineElements: (startRow, endRow) ->
    charWidth = @charWidth
    charHeight = @charHeight
    lines = @renderer.linesForRows(startRow, endRow)
    activeEditSession = @activeEditSession

    $$ ->
      for line in lines
        if fold = line.fold
          lineAttributes = { class: 'fold line', 'fold-id': fold.id }
          if activeEditSession.selectionIntersectsBufferRange(fold.getBufferRange())
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
    @activeEditSession.setSoftWrapColumn(softWrapColumn) if softWrapColumn

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
      path = Native.saveDialog()
      return false if not path
      @buffer.saveAs(path)
    else
      @buffer.save()

    true

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
      @updateCursorViews()
      @updateRenderedLines()

  getCursorView: (index) ->
    index ?= @cursorViews.length - 1
    @cursorViews[index]

  getCursorViews: ->
    new Array(@cursorViews...)

  removeAllCursorAndSelectionViews: ->
    cursorView.remove() for cursorView in @getCursorViews()
    selectionView.remove() for selectionView in @getSelectionViews()

  getCursor: (index) -> @activeEditSession.getCursor(index)
  getCursors: -> @activeEditSession.getCursors()
  getLastCursor: -> @activeEditSession.getLastCursor()
  moveCursorUp: -> @activeEditSession.moveCursorUp()
  moveCursorDown: -> @activeEditSession.moveCursorDown()
  moveCursorLeft: -> @activeEditSession.moveCursorLeft()
  moveCursorRight: -> @activeEditSession.moveCursorRight()
  moveCursorToNextWord: -> @activeEditSession.moveCursorToNextWord()
  moveCursorToBeginningOfWord: -> @activeEditSession.moveCursorToBeginningOfWord()
  moveCursorToEndOfWord: -> @activeEditSession.moveCursorToEndOfWord()
  moveCursorToTop: -> @activeEditSession.moveCursorToTop()
  moveCursorToBottom: -> @activeEditSession.moveCursorToBottom()
  moveCursorToBeginningOfLine: -> @activeEditSession.moveCursorToBeginningOfLine()
  moveCursorToFirstCharacterOfLine: -> @activeEditSession.moveCursorToFirstCharacterOfLine()
  moveCursorToEndOfLine: -> @activeEditSession.moveCursorToEndOfLine()
  setCursorScreenPosition: (position) -> @activeEditSession.setCursorScreenPosition(position)
  getCursorScreenPosition: -> @activeEditSession.getCursorScreenPosition()
  setCursorBufferPosition: (position) -> @activeEditSession.setCursorBufferPosition(position)
  getCursorBufferPosition: -> @activeEditSession.getCursorBufferPosition()

  getSelectionView: (index) ->
    index ?= @selectionViews.length - 1
    @selectionViews[index]

  getSelectionViews: ->
    new Array(@selectionViews...)

  getSelection: (index) -> @activeEditSession.getSelection(index)
  getSelections: -> @activeEditSession.getSelections()
  getSelectionsOrderedByBufferPosition: -> @activeEditSession.getSelectionsOrderedByBufferPosition()
  getLastSelectionInBuffer: -> @activeEditSession.getLastSelectionInBuffer()
  getSelectedText: -> @activeEditSession.getSelectedText()
  setSelectionBufferRange: (bufferRange, options) -> @activeEditSession.setSelectedBufferRange(bufferRange, options)
  setSelectedBufferRanges: (bufferRanges, options) -> @activeEditSession.setSelectedBufferRanges(bufferRanges, options)
  addSelectionForBufferRange: (bufferRange, options) -> @activeEditSession.addSelectionForBufferRange(bufferRange, options)
  selectRight: -> @activeEditSession.selectRight()
  selectLeft: -> @activeEditSession.selectLeft()
  selectUp: -> @activeEditSession.selectUp()
  selectDown: -> @activeEditSession.selectDown()
  selectToTop: -> @activeEditSession.selectToTop()
  selectToBottom: -> @activeEditSession.selectToBottom()
  selectAll: -> @activeEditSession.selectAll()
  selectToBeginningOfLine: -> @activeEditSession.selectToBeginningOfLine()
  selectToEndOfLine: -> @activeEditSession.selectToEndOfLine()
  selectToBeginningOfWord: -> @activeEditSession.selectToBeginningOfWord()
  selectToEndOfWord: -> @activeEditSession.selectToEndOfWord()
  selectToScreenPosition: (position) -> @activeEditSession.selectToScreenPosition(position)
  clearSelections: -> @activeEditSession.clearSelections()
  backspace: -> @activeEditSession.backspace()
  backspaceToBeginningOfWord: -> @activeEditSession.backspaceToBeginningOfWord()
  delete: -> @activeEditSession.delete()
  deleteToEndOfWord: -> @activeEditSession.deleteToEndOfWord()
  cutToEndOfLine: -> @activeEditSession.cutToEndOfLine()
  insertText: (text) -> @activeEditSession.insertText(text)
  insertNewline: -> @activeEditSession.insertNewline()
  insertNewlineBelow: -> @activeEditSession.insertNewlineBelow()
  insertTab: -> @activeEditSession.insertTab()
  indentSelectedRows: -> @activeEditSession.indentSelectedRows()
  outdentSelectedRows: -> @activeEditSession.outdentSelectedRows()

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

  cutSelection: -> @activeEditSession.cutSelectedText()
  copySelection: -> @activeEditSession.copySelectedText()
  paste: -> @activeEditSession.pasteText()

  undo: -> @activeEditSession.undo()
  redo: -> @activeEditSession.redo()

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
    return if @mini
    if @buffer.isModified()
      filename = if @buffer.getPath() then fs.base(@buffer.getPath()) else "untitled buffer"
      message = "'#{filename}' has changes, do you want to save them?"
      detailedMessage = "Your changes will be lost if you don't save them"
      buttons = [
        ["Save", => @save() and @removeActiveEditSession()]
        ["Cancel", =>]
        ["Don't save", => @removeActiveEditSession()]
      ]

      Native.alert message, detailedMessage, buttons
    else
      @removeActiveEditSession()

  unsubscribeFromBuffer: ->
    @buffer.off ".editor#{@id}"

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
    for cursorView in @getCursorViews()
      do (cursorView) -> cursorView.resetCursorAnimation()

  foldAll: -> @activeEditSession.foldAll()

  toggleFold: ->
    @activeEditSession.toggleFold()

  foldSelection: -> @activeEditSession.foldSelection()

  unfoldRow: (row) ->
    @renderer.largestFoldForBufferRow(row)?.destroy()

  logLines: (start, end) ->
    @renderer.logLines(start, end)

  toggleLineCommentsInSelection: ->
    @activeEditSession.toggleLineCommentsInSelection()

  logRenderedLines: ->
    @renderedLines.find('.line').each (n) ->
      console.log n, $(this).text()
