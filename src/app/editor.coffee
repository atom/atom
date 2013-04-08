{View, $$} = require 'space-pen'
Buffer = require 'text-buffer'
Gutter = require 'gutter'
Point = require 'point'
Range = require 'range'
EditSession = require 'edit-session'
CursorView = require 'cursor-view'
SelectionView = require 'selection-view'
fsUtils = require 'fs-utils'
$ = require 'jquery'
_ = require 'underscore'

module.exports =
class Editor extends View
  @configDefaults:
    fontSize: 20
    showInvisibles: false
    showIndentGuide: false
    showLineNumbers: true
    autoIndent: true
    autoIndentOnPaste: false
    nonWordCharacters: "./\\()\"':,.;<>~!@#$%^&*|+=[]{}`~?-"

  @nextEditorId: 1

  @content: (params) ->
    @div class: @classes(params), tabindex: -1, =>
      @subview 'gutter', new Gutter
      @input class: 'hidden-input', outlet: 'hiddenInput'
      @div class: 'scroll-view', outlet: 'scrollView', =>
        @div class: 'overlayer', outlet: 'overlayer'
        @div class: 'lines', outlet: 'renderedLines'
        @div class: 'underlayer', outlet: 'underlayer'
      @div class: 'vertical-scrollbar', outlet: 'verticalScrollbar', =>
        @div outlet: 'verticalScrollbarContent'

  @classes: ({mini} = {}) ->
    classes = ['editor']
    classes.push 'mini' if mini
    classes.join(' ')

  vScrollMargin: 2
  hScrollMargin: 10
  lineHeight: null
  charWidth: null
  charHeight: null
  cursorViews: null
  selectionViews: null
  lineCache: null
  isFocused: false
  activeEditSession: null
  attached: false
  lineOverdraw: 10
  pendingChanges: null
  newCursors: null
  newSelections: null
  redrawOnReattach: false

  initialize: (editSessionOrOptions) ->
    if editSessionOrOptions instanceof EditSession
      editSession = editSessionOrOptions
    else
      {editSession, @mini} = editSessionOrOptions ? {}

    requireStylesheet 'editor'

    @id = Editor.nextEditorId++
    @lineCache = []
    @configure()
    @bindKeys()
    @handleEvents()
    @cursorViews = []
    @selectionViews = []
    @pendingChanges = []
    @newCursors = []
    @newSelections = []

    if editSession?
      @edit(editSession)
    else if @mini
      @edit(new EditSession
        buffer: new Buffer()
        softWrap: false
        tabLength: 2
        softTabs: true
      )
    else
      throw new Error("Must supply an EditSession or mini: true")

  bindKeys: ->
    editorBindings =
      'core:move-left': @moveCursorLeft
      'core:move-right': @moveCursorRight
      'core:select-left': @selectLeft
      'core:select-right': @selectRight
      'core:select-all': @selectAll
      'core:backspace': @backspace
      'core:delete': @delete
      'core:undo': @undo
      'core:redo': @redo
      'core:cut': @cutSelection
      'core:copy': @copySelection
      'core:paste': @paste
      'editor:move-to-previous-word': @moveCursorToPreviousWord
      'editor:select-word': @selectWord
      'editor:newline': @insertNewline
      'editor:consolidate-selections': @consolidateSelections
      'editor:indent': @indent
      'editor:auto-indent': @autoIndent
      'editor:indent-selected-rows': @indentSelectedRows
      'editor:outdent-selected-rows': @outdentSelectedRows
      'editor:backspace-to-beginning-of-word': @backspaceToBeginningOfWord
      'editor:backspace-to-beginning-of-line': @backspaceToBeginningOfLine
      'editor:delete-to-end-of-word': @deleteToEndOfWord
      'editor:delete-line': @deleteLine
      'editor:cut-to-end-of-line': @cutToEndOfLine
      'editor:move-to-beginning-of-line': @moveCursorToBeginningOfLine
      'editor:move-to-end-of-line': @moveCursorToEndOfLine
      'editor:move-to-first-character-of-line': @moveCursorToFirstCharacterOfLine
      'editor:move-to-beginning-of-word': @moveCursorToBeginningOfWord
      'editor:move-to-end-of-word': @moveCursorToEndOfWord
      'editor:move-to-beginning-of-next-word': @moveCursorToBeginningOfNextWord
      'editor:select-to-end-of-line': @selectToEndOfLine
      'editor:select-to-beginning-of-line': @selectToBeginningOfLine
      'editor:select-to-end-of-word': @selectToEndOfWord
      'editor:select-to-beginning-of-word': @selectToBeginningOfWord
      'editor:select-to-beginning-of-next-word': @selectToBeginningOfNextWord
      'editor:add-selection-below': @addSelectionBelow
      'editor:add-selection-above': @addSelectionAbove
      'editor:select-line': @selectLine
      'editor:transpose': @transpose
      'editor:upper-case': @upperCase
      'editor:lower-case': @lowerCase

    unless @mini
      _.extend editorBindings,
        'core:move-up': @moveCursorUp
        'core:move-down': @moveCursorDown
        'core:move-to-top': @moveCursorToTop
        'core:move-to-bottom': @moveCursorToBottom
        'core:page-down': @pageDown
        'core:page-up': @pageUp
        'core:select-up': @selectUp
        'core:select-down': @selectDown
        'core:select-to-top': @selectToTop
        'core:select-to-bottom': @selectToBottom
        'editor:newline-below': @insertNewlineBelow
        'editor:newline-above': @insertNewlineAbove
        'editor:toggle-soft-tabs': @toggleSoftTabs
        'editor:toggle-soft-wrap': @toggleSoftWrap
        'editor:fold-all': @foldAll
        'editor:unfold-all': @unfoldAll
        'editor:fold-current-row': @foldCurrentRow
        'editor:unfold-current-row': @unfoldCurrentRow
        'editor:fold-selection': @foldSelection
        'editor:toggle-line-comments': @toggleLineCommentsInSelection
        'editor:log-cursor-scope': @logCursorScope
        'editor:checkout-head-revision': @checkoutHead
        'editor:copy-path': @copyPathToPasteboard
        'editor:move-line-up': @moveLineUp
        'editor:move-line-down': @moveLineDown
        'editor:duplicate-line': @duplicateLine
        'editor:join-line': @joinLine
        'editor:toggle-indent-guide': => config.set('editor.showIndentGuide', !config.get('editor.showIndentGuide'))
        'editor:save-debug-snapshot': @saveDebugSnapshot
        'editor:toggle-line-numbers': =>  config.set('editor.showLineNumbers', !config.get('editor.showLineNumbers'))

    documentation = {}
    for name, method of editorBindings
      do (name, method) =>
        @command name, (e) => method.call(this, e); false

  getCursor: -> @activeEditSession.getCursor()
  getCursors: -> @activeEditSession.getCursors()
  addCursorAtScreenPosition: (screenPosition) -> @activeEditSession.addCursorAtScreenPosition(screenPosition)
  addCursorAtBufferPosition: (bufferPosition) -> @activeEditSession.addCursorAtBufferPosition(bufferPosition)
  moveCursorUp: -> @activeEditSession.moveCursorUp()
  moveCursorDown: -> @activeEditSession.moveCursorDown()
  moveCursorLeft: -> @activeEditSession.moveCursorLeft()
  moveCursorRight: -> @activeEditSession.moveCursorRight()
  moveCursorToBeginningOfWord: -> @activeEditSession.moveCursorToBeginningOfWord()
  moveCursorToEndOfWord: -> @activeEditSession.moveCursorToEndOfWord()
  moveCursorToBeginningOfNextWord: -> @activeEditSession.moveCursorToEndOfWord(); @activeEditSession.moveCursorRight()
  moveCursorToTop: -> @activeEditSession.moveCursorToTop()
  moveCursorToBottom: -> @activeEditSession.moveCursorToBottom()
  moveCursorToBeginningOfLine: -> @activeEditSession.moveCursorToBeginningOfLine()
  moveCursorToFirstCharacterOfLine: -> @activeEditSession.moveCursorToFirstCharacterOfLine()
  moveCursorToEndOfLine: -> @activeEditSession.moveCursorToEndOfLine()
  moveLineUp: -> @activeEditSession.moveLineUp()
  moveLineDown: -> @activeEditSession.moveLineDown()
  setCursorScreenPosition: (position, options) -> @activeEditSession.setCursorScreenPosition(position, options)
  duplicateLine: -> @activeEditSession.duplicateLine()
  joinLine: -> @activeEditSession.joinLine()
  getCursorScreenPosition: -> @activeEditSession.getCursorScreenPosition()
  getCursorScreenRow: -> @activeEditSession.getCursorScreenRow()
  setCursorBufferPosition: (position, options) -> @activeEditSession.setCursorBufferPosition(position, options)
  getCursorBufferPosition: -> @activeEditSession.getCursorBufferPosition()
  getCurrentParagraphBufferRange: -> @activeEditSession.getCurrentParagraphBufferRange()
  getWordUnderCursor: (options) -> @activeEditSession.getWordUnderCursor(options)

  getSelection: (index) -> @activeEditSession.getSelection(index)
  getSelections: -> @activeEditSession.getSelections()
  getSelectionsOrderedByBufferPosition: -> @activeEditSession.getSelectionsOrderedByBufferPosition()
  getLastSelectionInBuffer: -> @activeEditSession.getLastSelectionInBuffer()
  getSelectedText: -> @activeEditSession.getSelectedText()
  getSelectedBufferRanges: -> @activeEditSession.getSelectedBufferRanges()
  getSelectedBufferRange: -> @activeEditSession.getSelectedBufferRange()
  setSelectedBufferRange: (bufferRange, options) -> @activeEditSession.setSelectedBufferRange(bufferRange, options)
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
  addSelectionBelow: -> @activeEditSession.addSelectionBelow()
  addSelectionAbove: -> @activeEditSession.addSelectionAbove()
  selectToBeginningOfWord: -> @activeEditSession.selectToBeginningOfWord()
  selectToEndOfWord: -> @activeEditSession.selectToEndOfWord()
  selectToBeginningOfNextWord: -> @activeEditSession.selectToEndOfWord(); @activeEditSession.selectRight()
  selectWord: -> @activeEditSession.selectWord()
  selectLine: -> @activeEditSession.selectLine()
  selectToScreenPosition: (position) -> @activeEditSession.selectToScreenPosition(position)
  transpose: -> @activeEditSession.transpose()
  upperCase: -> @activeEditSession.upperCase()
  lowerCase: -> @activeEditSession.lowerCase()
  clearSelections: -> @activeEditSession.clearSelections()

  backspace: -> @activeEditSession.backspace()
  backspaceToBeginningOfWord: -> @activeEditSession.backspaceToBeginningOfWord()
  backspaceToBeginningOfLine: -> @activeEditSession.backspaceToBeginningOfLine()
  delete: -> @activeEditSession.delete()
  deleteToEndOfWord: -> @activeEditSession.deleteToEndOfWord()
  deleteLine: -> @activeEditSession.deleteLine()
  cutToEndOfLine: -> @activeEditSession.cutToEndOfLine()
  insertText: (text, options) -> @activeEditSession.insertText(text, options)
  insertNewline: -> @activeEditSession.insertNewline()
  consolidateSelections: (e) -> e.abortKeyBinding() unless @activeEditSession.consolidateSelections()
  insertNewlineBelow: -> @activeEditSession.insertNewlineBelow()
  insertNewlineAbove: -> @activeEditSession.insertNewlineAbove()
  indent: (options) -> @activeEditSession.indent(options)
  autoIndent: (options) -> @activeEditSession.autoIndentSelectedRows(options)
  indentSelectedRows: -> @activeEditSession.indentSelectedRows()
  outdentSelectedRows: -> @activeEditSession.outdentSelectedRows()
  cutSelection: -> @activeEditSession.cutSelectedText()
  copySelection: -> @activeEditSession.copySelectedText()
  paste: -> @activeEditSession.pasteText()
  undo: -> @activeEditSession.undo()
  redo: -> @activeEditSession.redo()
  transact: (fn) -> @activeEditSession.transact(fn)
  commit: -> @activeEditSession.commit()
  abort: -> @activeEditSession.abort()
  createFold: (startRow, endRow) -> @activeEditSession.createFold(startRow, endRow)
  foldCurrentRow: -> @activeEditSession.foldCurrentRow()
  unfoldCurrentRow: -> @activeEditSession.unfoldCurrentRow()
  foldAll: -> @activeEditSession.foldAll()
  unfoldAll: -> @activeEditSession.unfoldAll()
  foldSelection: -> @activeEditSession.foldSelection()
  destroyFold: (foldId) -> @activeEditSession.destroyFold(foldId)
  destroyFoldsContainingBufferRow: (bufferRow) -> @activeEditSession.destroyFoldsContainingBufferRow(bufferRow)
  isFoldedAtScreenRow: (screenRow) -> @activeEditSession.isFoldedAtScreenRow(screenRow)
  isFoldedAtBufferRow: (bufferRow) -> @activeEditSession.isFoldedAtBufferRow(bufferRow)
  isFoldedAtCursorRow: -> @activeEditSession.isFoldedAtCursorRow()

  lineForScreenRow: (screenRow) -> @activeEditSession.lineForScreenRow(screenRow)
  linesForScreenRows: (start, end) -> @activeEditSession.linesForScreenRows(start, end)
  screenLineCount: -> @activeEditSession.screenLineCount()
  setSoftWrapColumn: (softWrapColumn) ->
    softWrapColumn ?= @calcSoftWrapColumn()
    @activeEditSession.setSoftWrapColumn(softWrapColumn) if softWrapColumn

  maxScreenLineLength: -> @activeEditSession.maxScreenLineLength()
  getLastScreenRow: -> @activeEditSession.getLastScreenRow()
  clipScreenPosition: (screenPosition, options={}) -> @activeEditSession.clipScreenPosition(screenPosition, options)
  screenPositionForBufferPosition: (position, options) -> @activeEditSession.screenPositionForBufferPosition(position, options)
  bufferPositionForScreenPosition: (position, options) -> @activeEditSession.bufferPositionForScreenPosition(position, options)
  screenRangeForBufferRange: (range) -> @activeEditSession.screenRangeForBufferRange(range)
  bufferRangeForScreenRange: (range) -> @activeEditSession.bufferRangeForScreenRange(range)
  bufferRowsForScreenRows: (startRow, endRow) -> @activeEditSession.bufferRowsForScreenRows(startRow, endRow)
  getLastScreenRow: -> @activeEditSession.getLastScreenRow()

  logCursorScope: ->
    console.log @activeEditSession.getCursorScopes()

  pageDown: ->
    newScrollTop = @scrollTop() + @scrollView[0].clientHeight
    @activeEditSession.moveCursorDown(@getPageRows())
    @scrollTop(newScrollTop,  adjustVerticalScrollbar: true)
  pageUp: ->
    newScrollTop = @scrollTop() - @scrollView[0].clientHeight
    @activeEditSession.moveCursorUp(@getPageRows())
    @scrollTop(newScrollTop,  adjustVerticalScrollbar: true)

  getPageRows: ->
    Math.max(1, Math.ceil(@scrollView[0].clientHeight / @lineHeight))

  setShowInvisibles: (showInvisibles) ->
    return if showInvisibles == @showInvisibles
    @showInvisibles = showInvisibles
    @resetDisplay()

  setInvisibles: (@invisibles={}) ->
    _.defaults @invisibles,
      eol: '\u00ac'
      space: '\u00b7'
      tab: '\u00bb'
      cr: '\u00a4'
    @resetDisplay()

  setShowIndentGuide: (showIndentGuide) ->
    return if showIndentGuide == @showIndentGuide
    @showIndentGuide = showIndentGuide
    @resetDisplay()

  checkoutHead: -> @getBuffer().checkoutHead()
  setText: (text) -> @getBuffer().setText(text)
  getText: -> @getBuffer().getText()
  getPath: -> @activeEditSession?.getPath()
  getLineCount: -> @getBuffer().getLineCount()
  getLastBufferRow: -> @getBuffer().getLastRow()
  getTextInRange: (range) -> @getBuffer().getTextInRange(range)
  getEofPosition: -> @getBuffer().getEofPosition()
  lineForBufferRow: (row) -> @getBuffer().lineForRow(row)
  lineLengthForBufferRow: (row) -> @getBuffer().lineLengthForRow(row)
  rangeForBufferRow: (row) -> @getBuffer().rangeForRow(row)
  scanInBufferRange: (args...) -> @getBuffer().scanInRange(args...)
  backwardsScanInBufferRange: (args...) -> @getBuffer().backwardsScanInRange(args...)

  configure: ->
    @observeConfig 'editor.showLineNumbers', (showLineNumbers) => @gutter.setShowLineNumbers(showLineNumbers)
    @observeConfig 'editor.showInvisibles', (showInvisibles) => @setShowInvisibles(showInvisibles)
    @observeConfig 'editor.showIndentGuide', (showIndentGuide) => @setShowIndentGuide(showIndentGuide)
    @observeConfig 'editor.invisibles', (invisibles) => @setInvisibles(invisibles)
    @observeConfig 'editor.fontSize', (fontSize) => @setFontSize(fontSize)
    @observeConfig 'editor.fontFamily', (fontFamily) => @setFontFamily(fontFamily)

  handleEvents: ->
    @on 'focus', =>
      @hiddenInput.focus()
      false

    @hiddenInput.on 'focus', =>
      @isFocused = true
      @addClass 'is-focused'

    @hiddenInput.on 'focusout', =>
      @isFocused = false
      @removeClass 'is-focused'

    @underlayer.on 'click', (e) =>
      return unless e.target is @underlayer[0]
      return unless e.offsetY > @overlayer.height()
      if e.shiftKey
        @selectToBottom()
      else
        @moveCursorToBottom()

    @overlayer.on 'mousedown', (e) =>
      @overlayer.hide()
      clickedElement = document.elementFromPoint(e.pageX, e.pageY)
      @overlayer.show()
      e.target = clickedElement
      $(clickedElement).trigger(e)
      false if @isFocused

    @renderedLines.on 'mousedown', '.fold.line', (e) =>
      @destroyFold($(e.currentTarget).attr('fold-id'))
      false

    onMouseDown = (e) =>
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
        @activeEditSession.selectWord() unless e.shiftKey
      else if clickCount == 3
        @activeEditSession.selectLine() unless e.shiftKey

      @selectOnMousemoveUntilMouseup() unless e.ctrlKey or e.originalEvent.which > 1

    @renderedLines.on 'mousedown', onMouseDown

    @on "textInput", (e) =>
      @insertText(e.originalEvent.data)
      false

    @scrollView.on 'mousewheel', (e) =>
      if delta = e.originalEvent.wheelDeltaY
        @scrollTop(@scrollTop() - delta)
        false

    @verticalScrollbar.on 'scroll', =>
      @scrollTop(@verticalScrollbar.scrollTop(), adjustVerticalScrollbar: false)

    unless @mini
      @gutter.widthChanged = (newWidth) =>
        @scrollView.css('left', newWidth + 'px')

    @scrollView.on 'scroll', =>
      if @scrollView.scrollLeft() == 0
        @gutter.removeClass('drop-shadow')
      else
        @gutter.addClass('drop-shadow')

  selectOnMousemoveUntilMouseup: ->
    lastMoveEvent = null
    moveHandler = (event = lastMoveEvent) =>
      if event
        @selectToScreenPosition(@screenPositionFromMouseEvent(event))
        lastMoveEvent = event

    $(document).on "mousemove.editor-#{@id}", moveHandler
    interval = setInterval(moveHandler, 20)

    $(document).one "mouseup.editor-#{@id}", =>
      clearInterval(interval)
      $(document).off 'mousemove', moveHandler
      reverse = @activeEditSession.getLastSelection().isReversed()
      @activeEditSession.mergeIntersectingSelections({reverse})
      @activeEditSession.finalizeSelections()
      @syncCursorAnimations()

  afterAttach: (onDom) ->
    return unless onDom
    @redraw() if @redrawOnReattach
    return if @attached
    @attached = true
    @calculateDimensions()
    @hiddenInput.width(@charWidth)
    @setSoftWrapColumn() if @activeEditSession.getSoftWrap()
    @subscribe $(window), "resize.editor-#{@id}", => @requestDisplayUpdate()
    @focus() if @isFocused

    @resetDisplay()

    @trigger 'editor:attached', [this]

  edit: (editSession) ->
    return if editSession is @activeEditSession

    if @activeEditSession
      @saveScrollPositionForActiveEditSession()
      @activeEditSession.off(".editor")

    @activeEditSession = editSession

    return unless @activeEditSession?

    @activeEditSession.setVisible(true)

    @activeEditSession.on "contents-conflicted.editor", =>
      @showBufferConflictAlert(@activeEditSession)

    @activeEditSession.on "path-changed.editor", =>
      @reloadGrammar()
      @trigger 'editor:path-changed'

    @activeEditSession.on "grammar-changed.editor", =>
      @trigger 'editor:grammar-changed'

    @trigger 'editor:path-changed'
    @resetDisplay()

    if @attached and @activeEditSession.buffer.isInConflict()
      _.defer => @showBufferConflictAlert(@activeEditSession) # Display after editSession has a chance to display

  getModel: ->
    @activeEditSession

  setModel: (editSession) ->
    @edit(editSession)

  getBuffer: -> @activeEditSession.buffer

  showBufferConflictAlert: (editSession) ->
    atom.confirm(
      editSession.getPath(),
      "Has changed on disk. Do you want to reload it?",
      "Reload", (=> editSession.buffer.reload()),
      "Cancel"
    )

  scrollTop: (scrollTop, options={}) ->
    return @cachedScrollTop or 0 unless scrollTop?
    maxScrollTop = @verticalScrollbar.prop('scrollHeight') - @verticalScrollbar.height()
    scrollTop = Math.floor(Math.max(0, Math.min(maxScrollTop, scrollTop)))
    return if scrollTop == @cachedScrollTop
    @cachedScrollTop = scrollTop

    @updateDisplay() if @attached

    @renderedLines.css('top', -scrollTop)
    @underlayer.css('top', -scrollTop)
    @overlayer.css('top', -scrollTop)
    @gutter.lineNumbers.css('top', -scrollTop)
    if options?.adjustVerticalScrollbar ? true
      @verticalScrollbar.scrollTop(scrollTop)

  scrollBottom: (scrollBottom) ->
    if scrollBottom?
      @scrollTop(scrollBottom - @scrollView.height())
    else
      @scrollTop() + @scrollView.height()

  scrollToBottom: ->
    @scrollBottom(@screenLineCount() * @lineHeight)

  scrollToBufferPosition: (bufferPosition, options) ->
    @scrollToPixelPosition(@pixelPositionForBufferPosition(bufferPosition), options)

  scrollToScreenPosition: (screenPosition, options) ->
    @scrollToPixelPosition(@pixelPositionForScreenPosition(screenPosition), options)

  scrollToPixelPosition: (pixelPosition, options) ->
    return unless @attached
    @scrollVertically(pixelPosition, options)
    @scrollHorizontally(pixelPosition)

  scrollVertically: (pixelPosition, {center}={}) ->
    scrollViewHeight = @scrollView.height()
    scrollTop = @scrollTop()
    scrollBottom = scrollTop + scrollViewHeight

    if center
      unless scrollTop < pixelPosition.top < scrollBottom
        @scrollTop(pixelPosition.top - (scrollViewHeight / 2))
    else
      linesInView = @scrollView.height() / @lineHeight
      maxScrollMargin = Math.floor((linesInView - 1) / 2)
      scrollMargin = Math.min(@vScrollMargin, maxScrollMargin)
      margin = scrollMargin * @lineHeight
      desiredTop = pixelPosition.top - margin
      desiredBottom = pixelPosition.top + @lineHeight + margin
      if desiredBottom > scrollBottom
        @scrollTop(desiredBottom - scrollViewHeight)
      else if desiredTop < scrollTop
        @scrollTop(desiredTop)

  scrollHorizontally: (pixelPosition) ->
    return if @activeEditSession.getSoftWrap()

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

  highlightFoldsContainingBufferRange: (bufferRange) ->
    screenLines = @linesForScreenRows(@firstRenderedScreenRow, @lastRenderedScreenRow)
    for screenLine, i in screenLines
      if fold = screenLine.fold
        screenRow = @firstRenderedScreenRow + i
        element = @lineElementForScreenRow(screenRow)

        if bufferRange.intersectsWith(fold.getBufferRange())
          element.addClass('selected')
        else
          element.removeClass('selected')

  setScrollPositionFromActiveEditSession: ->
    @scrollTop(@activeEditSession.scrollTop ? 0)
    @scrollView.scrollLeft(@activeEditSession.scrollLeft ? 0)

  saveScrollPositionForActiveEditSession: ->
    @activeEditSession.setScrollTop(@scrollTop())
    @activeEditSession.setScrollLeft(@scrollView.scrollLeft())

  toggleSoftTabs: ->
    @activeEditSession.setSoftTabs(not @activeEditSession.softTabs)

  toggleSoftWrap: ->
    @setSoftWrap(not @activeEditSession.getSoftWrap())

  calcSoftWrapColumn: ->
    if @activeEditSession.getSoftWrap()
      Math.floor(@scrollView.width() / @charWidth)
    else
      Infinity

  setSoftWrap: (softWrap, softWrapColumn=undefined) ->
    @activeEditSession.setSoftWrap(softWrap)
    @setSoftWrapColumn(softWrapColumn) if @attached
    if @activeEditSession.getSoftWrap()
      @addClass 'soft-wrap'
      @scrollView.scrollLeft(0)
      @_setSoftWrapColumn = => @setSoftWrapColumn()
      $(window).on "resize.editor-#{@id}", @_setSoftWrapColumn
    else
      @removeClass 'soft-wrap'
      $(window).off 'resize', @_setSoftWrapColumn

  setFontSize: (fontSize) ->
    headTag = $("head")
    styleTag = headTag.find("style.font-size")
    if styleTag.length == 0
      styleTag = $$ -> @style class: 'font-size'
      headTag.append styleTag

    styleTag.text(".editor {font-size: #{fontSize}px}")

    if @isOnDom()
      @redraw()
    else
      @redrawOnReattach = @attached

  getFontSize: ->
    parseInt(@css("font-size"))

  setFontFamily: (fontFamily) ->
    return if fontFamily == undefined
    headTag = $("head")
    styleTag = headTag.find("style.editor-font-family")
    if styleTag.length == 0
      styleTag = $$ -> @style class: 'editor-font-family'
      headTag.append styleTag

    styleTag.text(".editor {font-family: #{fontFamily}}")
    @redraw()

  getFontFamily: -> @css("font-family")

  clearFontFamily: ->
    $('head style.editor-font-family').remove()

  redraw: ->
    return unless @hasParent()
    return unless @attached
    @redrawOnReattach = false
    @calculateDimensions()
    @updatePaddingOfRenderedLines()
    @updateLayerDimensions()
    @requestDisplayUpdate()

  splitLeft: (items...) ->
    @getPane()?.splitLeft(items...).activeView

  splitRight: (items...) ->
    @getPane()?.splitRight(items...).activeView

  splitUp: (items...) ->
    @getPane()?.splitUp(items...).activeView

  splitDown: (items...) ->
    @getPane()?.splitDown(items...).activeView

  getPane: ->
    @parent('.item-views').parent('.pane').view()

  remove: (selector, keepData) ->
    return super if keepData or @removed
    @trigger 'editor:will-be-removed'
    super
    rootView?.focus()

  beforeRemove: ->
    @removed = true
    @activeEditSession?.destroy()
    $(window).off(".editor-#{@id}")
    $(document).off(".editor-#{@id}")

  getCursorView: (index) ->
    index ?= @cursorViews.length - 1
    @cursorViews[index]

  getCursorViews: ->
    new Array(@cursorViews...)

  addCursorView: (cursor, options) ->
    cursorView = new CursorView(cursor, this, options)
    @cursorViews.push(cursorView)
    @overlayer.append(cursorView)
    cursorView

  removeCursorView: (cursorView) ->
    _.remove(@cursorViews, cursorView)

  getSelectionView: (index) ->
    index ?= @selectionViews.length - 1
    @selectionViews[index]

  getSelectionViews: ->
    new Array(@selectionViews...)

  addSelectionView: (selection) ->
    selectionView = new SelectionView({editor: this, selection})
    @selectionViews.push(selectionView)
    @underlayer.append(selectionView)
    selectionView

  removeSelectionView: (selectionView) ->
    _.remove(@selectionViews, selectionView)

  removeAllCursorAndSelectionViews: ->
    cursorView.remove() for cursorView in @getCursorViews()
    selectionView.remove() for selectionView in @getSelectionViews()

  appendToLinesView: (view) ->
    @overlayer.append(view)

  calculateDimensions: ->
    fragment = $('<pre class="line" style="position: absolute; visibility: hidden;"><span>x</span></div>')
    @renderedLines.append(fragment)

    lineRect = fragment[0].getBoundingClientRect()
    charRect = fragment.find('span')[0].getBoundingClientRect()
    @lineHeight = lineRect.height
    @charWidth = charRect.width
    @charHeight = charRect.height
    @height(@lineHeight) if @mini
    fragment.remove()

  updateLayerDimensions: ->
    height = @lineHeight * @screenLineCount()
    unless @layerHeight == height
      @renderedLines.height(height)
      @underlayer.css('min-height', height)
      @overlayer.height(height)
      @layerHeight = height

      @verticalScrollbarContent.height(height)
      @scrollBottom(height) if @scrollBottom() > height

    minWidth = @charWidth * @maxScreenLineLength() + 20
    unless @layerMinWidth == minWidth
      @renderedLines.css('min-width', minWidth)
      @underlayer.css('min-width', minWidth)
      @overlayer.css('min-width', minWidth)
      @layerMinWidth = minWidth
      @trigger 'editor:min-width-changed'

  clearRenderedLines: ->
    @renderedLines.empty()
    @firstRenderedScreenRow = null
    @lastRenderedScreenRow = null

  resetDisplay: ->
    return unless @attached

    @clearRenderedLines()
    @removeAllCursorAndSelectionViews()
    @updateLayerDimensions()
    @setScrollPositionFromActiveEditSession()

    @activeEditSession.on 'selection-added.editor', (selection) =>
      @newCursors.push(selection.cursor)
      @newSelections.push(selection)
      @requestDisplayUpdate()

    @activeEditSession.on 'screen-lines-changed.editor', (e) => @handleScreenLinesChange(e)

    @newCursors = @activeEditSession.getCursors()
    @newSelections = @activeEditSession.getSelections()
    @updateDisplay(suppressAutoScroll: true)

  requestDisplayUpdate: ->
    return if @pendingDisplayUpdate
    @pendingDisplayUpdate = true
    _.nextTick =>
      @updateDisplay()
      @pendingDisplayUpdate = false

  updateDisplay: (options={}) ->
    return unless @attached and @activeEditSession
    return if @activeEditSession.destroyed
    @updateRenderedLines()
    @highlightCursorLine()
    @updateCursorViews()
    @updateSelectionViews()
    @autoscroll(options)
    @trigger 'editor:display-updated'

  updateCursorViews: ->
    if @newCursors.length > 0
      @addCursorView(cursor) for cursor in @newCursors when not cursor.destroyed
      @syncCursorAnimations()
      @newCursors = []

    for cursorView in @getCursorViews()
      if cursorView.needsRemoval
        cursorView.remove()
      else if cursorView.needsUpdate
        cursorView.updateDisplay()

  updateSelectionViews: ->
    if @newSelections.length > 0
      @addSelectionView(selection) for selection in @newSelections when not selection.destroyed
      @newSelections = []

    for selectionView in @getSelectionViews()
      if selectionView.needsRemoval
        selectionView.remove()
      else
        selectionView.updateDisplay()

  syncCursorAnimations: ->
    for cursorView in @getCursorViews()
      do (cursorView) -> cursorView.resetBlinking()

  autoscroll: (options={}) ->
    for cursorView in @getCursorViews()
      if !options.suppressAutoScroll and cursorView.needsAutoscroll()
        @scrollToPixelPosition(cursorView.getPixelPosition())
      cursorView.clearAutoscroll()

    for selectionView in @getSelectionViews()
      if !options.suppressAutoScroll and selectionView.needsAutoscroll()
        @scrollToPixelPosition(selectionView.getCenterPixelPosition(), center: true)
        selectionView.highlight()
      selectionView.clearAutoscroll()

  updateRenderedLines: ->
    firstVisibleScreenRow = @getFirstVisibleScreenRow()
    lastVisibleScreenRow = @getLastVisibleScreenRow()

    if @firstRenderedScreenRow? and firstVisibleScreenRow >= @firstRenderedScreenRow and lastVisibleScreenRow <= @lastRenderedScreenRow
      renderFrom = @firstRenderedScreenRow
      renderTo = Math.min(@getLastScreenRow(), @lastRenderedScreenRow)
    else
      renderFrom = Math.max(0, firstVisibleScreenRow - @lineOverdraw)
      renderTo = Math.min(@getLastScreenRow(), lastVisibleScreenRow + @lineOverdraw)

    if @pendingChanges.length == 0 and @firstRenderedScreenRow and @firstRenderedScreenRow <= renderFrom and renderTo <= @lastRenderedScreenRow
      return

    @gutter.updateLineNumbers(@pendingChanges, renderFrom, renderTo)
    intactRanges = @computeIntactRanges()
    @pendingChanges = []
    @truncateIntactRanges(intactRanges, renderFrom, renderTo)
    @clearDirtyRanges(intactRanges)
    @fillDirtyRanges(intactRanges, renderFrom, renderTo)
    @firstRenderedScreenRow = renderFrom
    @lastRenderedScreenRow = renderTo
    @updateLayerDimensions()
    @updatePaddingOfRenderedLines()

  computeIntactRanges: ->
    return [] if !@firstRenderedScreenRow? and !@lastRenderedScreenRow?

    intactRanges = [{start: @firstRenderedScreenRow, end: @lastRenderedScreenRow, domStart: 0}]

    if @showIndentGuide
      trailingEmptyLineChanges = []
      for change in @pendingChanges
        continue unless change.bufferDelta?
        start = change.end + change.bufferDelta + 1
        continue unless @lineForBufferRow(start) is ''
        end = start
        end++ while @lineForBufferRow(end + 1) is ''
        trailingEmptyLineChanges.push({start, end, screenDelta: 0})
        @pendingChanges.push(trailingEmptyLineChanges...)

    for change in @pendingChanges
      newIntactRanges = []
      for range in intactRanges
        if change.end < range.start and change.screenDelta != 0
          newIntactRanges.push(
            start: range.start + change.screenDelta
            end: range.end + change.screenDelta
            domStart: range.domStart
          )
        else if change.end < range.start or change.start > range.end
          newIntactRanges.push(range)
        else
          if change.start > range.start
            newIntactRanges.push(
              start: range.start
              end: change.start - 1
              domStart: range.domStart)
          if change.end < range.end
            newIntactRanges.push(
              start: change.end + change.screenDelta + 1
              end: range.end + change.screenDelta
              domStart: range.domStart + change.end + 1 - range.start
            )
      intactRanges = newIntactRanges
    @pendingChanges = []
    intactRanges

  truncateIntactRanges: (intactRanges, renderFrom, renderTo) ->
    i = 0
    while i < intactRanges.length
      range = intactRanges[i]
      if range.start < renderFrom
        range.domStart += renderFrom - range.start
        range.start = renderFrom
      if range.end > renderTo
        range.end = renderTo
      if range.start >= range.end
        intactRanges.splice(i--, 1)
      i++
    intactRanges.sort (a, b) -> a.domStart - b.domStart

  clearDirtyRanges: (intactRanges) ->
    renderedLines = @renderedLines[0]
    killLine = (line) ->
      next = line.nextSibling
      renderedLines.removeChild(line)
      next

    if intactRanges.length == 0
      @renderedLines.empty()
    else
      domPosition = 0
      currentLine = renderedLines.firstChild
      for intactRange in intactRanges
        while intactRange.domStart > domPosition
          currentLine = killLine(currentLine)
          domPosition++
        for i in [intactRange.start..intactRange.end]
          currentLine = currentLine.nextSibling
          domPosition++
      while currentLine
        currentLine = killLine(currentLine)

  fillDirtyRanges: (intactRanges, renderFrom, renderTo) ->
    renderedLines = @renderedLines[0]
    nextIntact = intactRanges.shift()
    currentLine = renderedLines.firstChild

    row = renderFrom
    while row <= renderTo
      if row == nextIntact?.end + 1
        nextIntact = intactRanges.shift()
      if !nextIntact or row < nextIntact.start
        if nextIntact
          dirtyRangeEnd = nextIntact.start - 1
        else
          dirtyRangeEnd = renderTo

        for lineElement in @buildLineElementsForScreenRows(row, dirtyRangeEnd)
          renderedLines.insertBefore(lineElement, currentLine)
          row++
      else
        currentLine = currentLine.nextSibling
        row++

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
    Math.max(0, Math.ceil((@scrollTop() + @scrollView.height()) / @lineHeight) - 1)

  isScreenRowVisible: (row) ->
    @getFirstVisibleScreenRow() <= row <= @getLastVisibleScreenRow()

  handleScreenLinesChange: (change) ->
    @pendingChanges.push(change)
    @requestDisplayUpdate()

  buildLineElementForScreenRow: (screenRow) ->
    @buildLineElementsForScreenRows(screenRow, screenRow)[0]

  buildLineElementsForScreenRows: (startRow, endRow) ->
    div = document.createElement('div')
    div.innerHTML = @buildLinesHtml(startRow, endRow)
    new Array(div.children...)

  buildLinesHtml: (startRow, endRow) ->
    lines = @activeEditSession.linesForScreenRows(startRow, endRow)
    htmlLines = []
    screenRow = startRow
    for line in @activeEditSession.linesForScreenRows(startRow, endRow)
      htmlLines.push(@buildLineHtml(line, screenRow++))
    htmlLines.join('\n\n')

  buildEmptyLineHtml: (screenRow) ->
    if not @mini and @showIndentGuide
      indentation = 0
      while --screenRow >= 0
        bufferRow = @activeEditSession.bufferPositionForScreenPosition([screenRow]).row
        bufferLine = @activeEditSession.lineForBufferRow(bufferRow)
        unless bufferLine is ''
          indentation = Math.ceil(@activeEditSession.indentLevelForLine(bufferLine))
          break

      if indentation > 0
        indentationHtml = "<span class='indent-guide'>#{_.multiplyString(' ', @activeEditSession.getTabLength())}</span>"
        return _.multiplyString(indentationHtml, indentation)

    return '&nbsp;' unless @showInvisibles

  buildLineHtml: (screenLine, screenRow) ->
    scopeStack = []
    line = []

    updateScopeStack = (desiredScopes) ->
      excessScopes = scopeStack.length - desiredScopes.length
      _.times(excessScopes, popScope) if excessScopes > 0

      # pop until common prefix
      for i in [scopeStack.length..0]
        break if _.isEqual(scopeStack[0...i], desiredScopes[0...i])
        popScope()

      # push on top of common prefix until scopeStack == desiredScopes
      for j in [i...desiredScopes.length]
        pushScope(desiredScopes[j])

    pushScope = (scope) ->
      scopeStack.push(scope)
      line.push("<span class=\"#{scope.replace(/\./g, ' ')}\">")

    popScope = ->
      scopeStack.pop()
      line.push("</span>")

    if fold = screenLine.fold
      lineAttributes = { class: 'fold line', 'fold-id': fold.id }
    else
      lineAttributes = { class: 'line' }

    attributePairs = []
    attributePairs.push "#{attributeName}=\"#{value}\"" for attributeName, value of lineAttributes
    line.push("<pre #{attributePairs.join(' ')}>")

    invisibles = @invisibles if @showInvisibles

    if screenLine.text == ''
      html = @buildEmptyLineHtml(screenRow)
      line.push(html) if html
    else
      firstNonWhitespacePosition = screenLine.text.search(/\S/)
      firstTrailingWhitespacePosition = screenLine.text.search(/\s*$/)
      lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
      position = 0
      for token in screenLine.tokens
        updateScopeStack(token.scopes)
        hasLeadingWhitespace =  position < firstNonWhitespacePosition
        hasTrailingWhitespace = position + token.value.length > firstTrailingWhitespacePosition
        hasIndentGuide = @showIndentGuide and (hasLeadingWhitespace or lineIsWhitespaceOnly)
        line.push(token.getValueAsHtml({invisibles, hasLeadingWhitespace, hasTrailingWhitespace, hasIndentGuide}))
        position += token.value.length

    popScope() while scopeStack.length > 0
    if invisibles and not @mini and not screenLine.isSoftWrapped()
      if invisibles.cr and screenLine.lineEnding is '\r\n'
        line.push("<span class='invisible'>#{invisibles.cr}</span>")
      if invisibles.eol
        line.push("<span class='invisible'>#{invisibles.eol}</span>")

    line.push("<span class='fold-marker'/>") if fold

    line.push('</pre>')
    line.join('')

  lineElementForScreenRow: (screenRow) ->
    @renderedLines.children(":eq(#{screenRow - @firstRenderedScreenRow})")

  toggleLineCommentsInSelection: ->
    @activeEditSession.toggleLineCommentsInSelection()

  pixelPositionForBufferPosition: (position) ->
    @pixelPositionForScreenPosition(@screenPositionForBufferPosition(position))

  pixelPositionForScreenPosition: (position) ->
    return { top: 0, left: 0 } unless @isOnDom()
    {row, column} = Point.fromObject(position)
    actualRow = Math.floor(row)

    lineElement = existingLineElement = @lineElementForScreenRow(actualRow)[0]
    unless existingLineElement
      lineElement = @buildLineElementForScreenRow(actualRow)
      @renderedLines.append(lineElement)
    left = @positionLeftForLineAndColumn(lineElement, column)
    unless existingLineElement
      @renderedLines[0].removeChild(lineElement)
    { top: row * @lineHeight, left }

  positionLeftForLineAndColumn: (lineElement, column) ->
    return 0 if column is 0
    delta = 0
    iterator = document.createNodeIterator(lineElement, NodeFilter.SHOW_TEXT, acceptNode: -> NodeFilter.FILTER_ACCEPT)
    while textNode = iterator.nextNode()
      nextDelta = delta + textNode.textContent.length
      if nextDelta >= column
        offset = column - delta
        break
      delta = nextDelta

    range = document.createRange()
    range.setEnd(textNode, offset)
    range.collapse()
    leftPixels = range.getClientRects()[0].left - @scrollView.offset().left + @scrollView.scrollLeft()
    range.detach()
    leftPixels

  pixelOffsUtilsetForScreenPosition: (position) ->
    {top, left} = @pixelPositionForScreenPosition(position)
    offset = @renderedLines.offset()
    {top: top + offset.top, left: left + offset.left}

  screenPositionFromMouseEvent: (e) ->
    { pageX, pageY } = e

    editorRelativeTop = pageY - @scrollView.offset().top + @scrollTop()
    row = Math.floor(editorRelativeTop / @lineHeight)
    column = 0

    if lineElement = @lineElementForScreenRow(row)[0]
      range = document.createRange()
      iterator = document.createNodeIterator(lineElement, NodeFilter.SHOW_TEXT, acceptNode: -> NodeFilter.FILTER_ACCEPT)
      while node = iterator.nextNode()
        range.selectNodeContents(node)
        column += node.textContent.length
        {left, right} = range.getClientRects()[0]
        break if left <= pageX <= right

      if node
        for characterPosition in [node.textContent.length...0]
          range.setStart(node, characterPosition - 1)
          range.setEnd(node, characterPosition)
          {left, right, width} = range.getClientRects()[0]
          break if left <= pageX - width / 2 <= right
          column--

      range.detach()

    new Point(row, column)

  highlightCursorLine: ->
    return if @mini

    @highlightedLine?.removeClass('cursor-line')
    if @getSelection().isEmpty()
      @highlightedLine = @lineElementForScreenRow(@getCursorScreenRow())
      @highlightedLine.addClass('cursor-line')
    else
      @highlightedLine = null

  getGrammar: ->
    @activeEditSession.getGrammar()

  setGrammar: (grammar) ->
    throw new Error("Only mini-editors can explicity set their grammar") unless @mini
    @activeEditSession.setGrammar(grammar)

  reloadGrammar: ->
    @activeEditSession.reloadGrammar()

  bindToKeyedEvent: (key, event, callback) ->
    binding = {}
    binding[key] = event
    window.keymap.bindKeys '.editor', binding
    @on event, =>
      callback(this, event)

  replaceSelectedText: (replaceFn) ->
    selection = @getSelection()
    return false if selection.isEmpty()

    text = replaceFn(@getTextInRange(selection.getBufferRange()))
    return false if text is null or text is undefined

    @insertText(text, select: true)
    true

  copyPathToPasteboard: ->
    path = @getPath()
    pasteboard.write(path) if path?

  saveDebugSnapshot: ->
    atom.showSaveDialog (path) =>
      fsUtils.write(path, @getDebugSnapshot()) if path

  getDebugSnapshot: ->
    [
      "Debug Snapshot: #{@getPath()}"
      @getRenderedLinesDebugSnapshot()
      @activeEditSession.getDebugSnapshot()
      @getBuffer().getDebugSnapshot()
    ].join('\n\n')

  getRenderedLinesDebugSnapshot: ->
    lines = ['Rendered Lines:']
    firstRenderedScreenRow = @firstRenderedScreenRow
    @renderedLines.find('.line').each (n) ->
      lines.push "#{firstRenderedScreenRow + n}: #{$(this).text()}"
    lines.join('\n')

  logScreenLines: (start, end) ->
    @activeEditSession.logScreenLines(start, end)

  logRenderedLines: ->
    @renderedLines.find('.line').each (n) ->
      console.log n, $(this).text()
