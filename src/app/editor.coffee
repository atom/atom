{View, $$} = require 'space-pen'
Buffer = require 'buffer'
Gutter = require 'gutter'
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
  @configDefaults:
    fontSize: 20
    showInvisibles: false
    autosave: false
    autoIndent: true
    autoIndentOnPaste: false

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
  editSessions: null
  attached: false
  lineOverdraw: 10
  pendingChanges: null
  newCursors: null
  newSelections: null

  @deserialize: (state, rootView) ->
    editSessions = state.editSessions.map (state) -> EditSession.deserialize(state, rootView.project)
    editor = new Editor(editSession: editSessions[state.activeEditSessionIndex], mini: state.mini)
    editor.editSessions = editSessions
    editor.isFocused = state.isFocused
    editor

  initialize: ({editSession, @mini} = {}) ->
    requireStylesheet 'editor.css'

    @lineCache = []
    @configure()
    @bindKeys()
    @handleEvents()
    @cursorViews = []
    @selectionViews = []
    @editSessions = []
    @pendingChanges = []
    @newCursors = []
    @newSelections = []

    if editSession?
      @editSessions.push editSession
      @setActiveEditSessionIndex(0)
    else if @mini
      editSession = new EditSession
        buffer: new Buffer()
        softWrap: false
        tabLength: 2
        softTabs: true

      @editSessions.push editSession
      @setActiveEditSessionIndex(0)
    else
      throw new Error("Editor initialization requires an editSession")

  serialize: ->
    @saveScrollPositionForActiveEditSession()
    viewClass: "Editor"
    editSessions: @editSessions.map (session) -> session.serialize()
    activeEditSessionIndex: @getActiveEditSessionIndex()
    isFocused: @isFocused

  copy: ->
    Editor.deserialize(@serialize(), @rootView())

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
      'editor:indent': @indent
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
      'editor:select-to-end-of-line': @selectToEndOfLine
      'editor:select-to-beginning-of-line': @selectToBeginningOfLine
      'editor:select-to-end-of-word': @selectToEndOfWord
      'editor:select-to-beginning-of-word': @selectToBeginningOfWord
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
        'core:close': @destroyActiveEditSession
        'editor:save': @save
        'editor:newline-below': @insertNewlineBelow
        'editor:toggle-soft-tabs': @toggleSoftTabs
        'editor:toggle-soft-wrap': @toggleSoftWrap
        'editor:fold-all': @foldAll
        'editor:unfold-all': @unfoldAll
        'editor:fold-current-row': @foldCurrentRow
        'editor:unfold-current-row': @unfoldCurrentRow
        'editor:fold-selection': @foldSelection
        'editor:split-left': @splitLeft
        'editor:split-right': @splitRight
        'editor:split-up': @splitUp
        'editor:split-down': @splitDown
        'editor:show-next-buffer': @loadNextEditSession
        'editor:show-buffer-1': => @setActiveEditSessionIndex(0) if @editSessions[0]
        'editor:show-buffer-2': => @setActiveEditSessionIndex(1) if @editSessions[1]
        'editor:show-buffer-3': => @setActiveEditSessionIndex(2) if @editSessions[2]
        'editor:show-buffer-4': => @setActiveEditSessionIndex(3) if @editSessions[3]
        'editor:show-buffer-5': => @setActiveEditSessionIndex(4) if @editSessions[4]
        'editor:show-buffer-6': => @setActiveEditSessionIndex(5) if @editSessions[5]
        'editor:show-buffer-7': => @setActiveEditSessionIndex(6) if @editSessions[6]
        'editor:show-buffer-8': => @setActiveEditSessionIndex(7) if @editSessions[7]
        'editor:show-buffer-9': => @setActiveEditSessionIndex(8) if @editSessions[8]
        'editor:show-previous-buffer': @loadPreviousEditSession
        'editor:toggle-line-comments': @toggleLineCommentsInSelection
        'editor:log-cursor-scope': @logCursorScope
        'editor:checkout-head-revision': @checkoutHead
        'editor:close-other-edit-sessions': @destroyInactiveEditSessions
        'editor:close-all-edit-sessions': @destroyAllEditSessions
        'editor:select-grammar': @selectGrammar

    documentation = {}
    for name, method of editorBindings
      do (name, method) =>
        @command name, => method.call(this); false

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
  moveCursorToTop: -> @activeEditSession.moveCursorToTop()
  moveCursorToBottom: -> @activeEditSession.moveCursorToBottom()
  moveCursorToBeginningOfLine: -> @activeEditSession.moveCursorToBeginningOfLine()
  moveCursorToFirstCharacterOfLine: -> @activeEditSession.moveCursorToFirstCharacterOfLine()
  moveCursorToEndOfLine: -> @activeEditSession.moveCursorToEndOfLine()
  setCursorScreenPosition: (position) -> @activeEditSession.setCursorScreenPosition(position)
  getCursorScreenPosition: -> @activeEditSession.getCursorScreenPosition()
  getCursorScreenRow: -> @activeEditSession.getCursorScreenRow()
  setCursorBufferPosition: (position, options) -> @activeEditSession.setCursorBufferPosition(position, options)
  getCursorBufferPosition: -> @activeEditSession.getCursorBufferPosition()
  getCurrentParagraphBufferRange: -> @activeEditSession.getCurrentParagraphBufferRange()

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
  selectToBeginningOfWord: -> @activeEditSession.selectToBeginningOfWord()
  selectToEndOfWord: -> @activeEditSession.selectToEndOfWord()
  selectWord: -> @activeEditSession.selectWord()
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
  insertNewlineBelow: -> @activeEditSession.insertNewlineBelow()
  indent: (options) -> @activeEditSession.indent(options)
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
      eol: '\u00ac',
      space: '\u2022',
      tab: '\u00bb'
    @resetDisplay()

  checkoutHead: -> @getBuffer().checkoutHead()
  setText: (text) -> @getBuffer().setText(text)
  getText: -> @getBuffer().getText()
  getPath: -> @getBuffer().getPath()
  getLineCount: -> @getBuffer().getLineCount()
  getLastBufferRow: -> @getBuffer().getLastRow()
  getTextInRange: (range) -> @getBuffer().getTextInRange(range)
  getEofPosition: -> @getBuffer().getEofPosition()
  lineForBufferRow: (row) -> @getBuffer().lineForRow(row)
  lineLengthForBufferRow: (row) -> @getBuffer().lineLengthForRow(row)
  rangeForBufferRow: (row) -> @getBuffer().rangeForRow(row)
  scanInRange: (args...) -> @getBuffer().scanInRange(args...)
  backwardsScanInRange: (args...) -> @getBuffer().backwardsScanInRange(args...)

  configure: ->
    @observeConfig 'editor.showInvisibles', (showInvisibles) => @setShowInvisibles(showInvisibles)
    @observeConfig 'editor.invisibles', (invisibles) => @setInvisibles(invisibles)
    @observeConfig 'editor.fontSize', (fontSize) => @setFontSize(fontSize)

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
      @autosave() if config.get "editor.autosave"

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
        @activeEditSession.selectWord() unless e.shiftKey
      else if clickCount == 3
        @activeEditSession.selectLine() unless e.shiftKey

      @selectOnMousemoveUntilMouseup()

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

    $(document).on 'mousemove', moveHandler
    interval = setInterval(moveHandler, 20)

    $(document).one 'mouseup', =>
      clearInterval(interval)
      $(document).off 'mousemove', moveHandler
      reverse = @activeEditSession.getLastSelection().isReversed()
      @activeEditSession.mergeIntersectingSelections({reverse})
      @activeEditSession.finalizeSelections()
      @syncCursorAnimations()

  afterAttach: (onDom) ->
    return if @attached or not onDom
    @attached = true
    @calculateDimensions()
    @hiddenInput.width(@charWidth)
    @setSoftWrapColumn() if @activeEditSession.getSoftWrap()
    @subscribe $(window), "resize", => @requestDisplayUpdate()
    @focus() if @isFocused

    @resetDisplay()

    @trigger 'editor:attached', [this]

  edit: (editSession) ->
    index = @editSessions.indexOf(editSession)

    if index == -1
      index = @editSessions.length
      @editSessions.push(editSession)
      @trigger 'editor:edit-session-added', [editSession, index]

    @setActiveEditSessionIndex(index)

  getBuffer: -> @activeEditSession.buffer

  destroyActiveEditSession: ->
    @destroyEditSessionIndex(@getActiveEditSessionIndex())

  destroyEditSessionIndex: (index, callback) ->
    return if @mini

    editSession = @editSessions[index]
    destroySession = =>
      if index is @getActiveEditSessionIndex() and @editSessions.length > 1
        @loadPreviousEditSession()
      _.remove(@editSessions, editSession)
      editSession.destroy()
      @trigger 'editor:edit-session-removed', [editSession, index]
      @remove() if @editSessions.length is 0
      callback(index) if callback

    if editSession.isModified() and not editSession.hasEditors()
      @promptToSaveDirtySession(editSession, destroySession)
    else
      destroySession(editSession)

  destroyInactiveEditSessions: ->
    destroyIndex = (index) =>
      index++ if @activeEditSession is @editSessions[index]
      @destroyEditSessionIndex(index, destroyIndex) if @editSessions[index]
    destroyIndex(0)

  destroyAllEditSessions: ->
    destroyIndex = (index) =>
      @destroyEditSessionIndex(index, destroyIndex) if @editSessions[index]
    destroyIndex(0)

  loadNextEditSession: ->
    nextIndex = (@getActiveEditSessionIndex() + 1) % @editSessions.length
    @setActiveEditSessionIndex(nextIndex)

  loadPreviousEditSession: ->
    previousIndex = @getActiveEditSessionIndex() - 1
    previousIndex = @editSessions.length - 1 if previousIndex < 0
    @setActiveEditSessionIndex(previousIndex)

  getActiveEditSessionIndex: ->
    return index for session, index in @editSessions when session == @activeEditSession

  setActiveEditSessionIndex: (index) ->
    throw new Error("Edit session not found") unless @editSessions[index]

    if @activeEditSession
      @autosave() if config.get "editor.autosave"
      @saveScrollPositionForActiveEditSession()
      @activeEditSession.off(".editor")

    @activeEditSession = @editSessions[index]
    @activeEditSession.setVisible(true)

    @activeEditSession.on "contents-conflicted.editor", =>
      @showBufferConflictAlert(@activeEditSession)

    @activeEditSession.on "path-changed.editor", =>
      @reloadGrammar()
      @trigger 'editor:path-changed'

    @trigger 'editor:path-changed'
    @trigger 'editor:active-edit-session-changed', [@activeEditSession, index]
    @resetDisplay()

    if @attached and @activeEditSession.buffer.isInConflict()
      setTimeout(( =>@showBufferConflictAlert(@activeEditSession)), 0) # Display after editSession has a chance to display

  showBufferConflictAlert: (editSession) ->
    atom.confirm(
      editSession.getPath(),
      "Has changed on disk. Do you want to reload it?",
      "Reload", (=> editSession.buffer.reload()),
      "Cancel"
    )

  activateEditSessionForPath: (path) ->
    for editSession, index in @editSessions
      if editSession.buffer.getPath() == path
        @setActiveEditSessionIndex(index)
        return @activeEditSession
    false

  getOpenBufferPaths: ->
    editSession.buffer.getPath() for editSession in @editSessions when editSession.buffer.getPath()?

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
      @_setSoftWrapColumn = => @setSoftWrapColumn()
      $(window).on "resize", @_setSoftWrapColumn
    else
      @removeClass 'soft-wrap'
      $(window).off 'resize', @_setSoftWrapColumn

  save: (session=@activeEditSession, onSuccess) ->
    if @getPath()
      session.save()
      onSuccess?()
    else
      atom.showSaveDialog (path) =>
        if path
          session.saveAs(path)
          onSuccess?()

  autosave: ->
    @save() if @getPath()?

  setFontSize: (@fontSize) ->
    if fontSize?
      @css('font-size', fontSize + 'px')
      return unless @attached
      @calculateDimensions()
      @updatePaddingOfRenderedLines()
      @updateLayerDimensions()
      @requestDisplayUpdate()

  getFontSize: -> @fontSize

  newSplitEditor: (editSession) ->
    new Editor { editSession: editSession ? @activeEditSession.copy() }

  splitLeft: (editSession) ->
    @pane()?.splitLeft(@newSplitEditor(editSession)).wrappedView

  splitRight: (editSession) ->
    @pane()?.splitRight(@newSplitEditor(editSession)).wrappedView

  splitUp: (editSession) ->
    @pane()?.splitUp(@newSplitEditor(editSession)).wrappedView

  splitDown: (editSession) ->
    @pane()?.splitDown(@newSplitEditor(editSession)).wrappedView

  pane: ->
    @parent('.pane').view()

  rootView: ->
    @parents('#root-view').view()

  promptToSaveDirtySession: (session, callback) ->
    path = session.getPath()
    filename = if path then fs.base(path) else "untitled buffer"
    atom.confirm(
      "'#{filename}' has changes, do you want to save them?"
      "Your changes will be lost if you don't save them"
      "Save", => @save(session, callback),
      "Cancel", null
      "Don't save", callback
    )

  remove: (selector, keepData) ->
    return super if keepData

    @trigger 'editor:will-be-removed'

    @destroyEditSessions()

    if @pane() then @pane().remove() else super
    rootView?.focus()

  getEditSessions: ->
    new Array(@editSessions...)

  destroyEditSessions: ->
    for session in @getEditSessions()
      session.destroy()

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
    @gutter.calculateWidth()

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

  requestDisplayUpdate: ()->
    return if @pendingDisplayUpdate
    @pendingDisplayUpdate = true
    _.nextTick =>
      @updateDisplay()
      @pendingDisplayUpdate = false

  updateDisplay: (options={}) ->
    return unless @attached
    @updateRenderedLines()
    @highlightCursorLine()
    @updateCursorViews()
    @updateSelectionViews()
    @autoscroll(options)

  updateCursorViews: ->
    if @newCursors.length > 0
      @addCursorView(cursor) for cursor in @newCursors
      @syncCursorAnimations()
      @newCursors = []

    for cursorView in @getCursorViews()
      if cursorView.needsRemoval
        cursorView.remove()
      else if cursorView.needsUpdate
        cursorView.updateDisplay()

  updateSelectionViews: ->
    if @newSelections.length > 0
      @addSelectionView(selection) for selection in @newSelections
      @newSelections = []

    for selectionView in @getSelectionViews()
      if selectionView.destroyed
        selectionView.remove()
      else
        selectionView.updateDisplay()

  syncCursorAnimations: ->
    for cursorView in @getCursorViews()
      do (cursorView) -> cursorView.resetBlinking()

  autoscroll: (options={}) ->
    for cursorView in @getCursorViews() when cursorView.needsAutoscroll()
      @scrollToPixelPosition(cursorView.getPixelPosition()) unless options.suppressAutoScroll
      cursorView.autoscrolled()

    for selectionView in @getSelectionViews() when selectionView.needsAutoscroll()
      @scrollToPixelPosition(selectionView.getCenterPixelPosition(), center: true)
      selectionView.autoscrolled()

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

  buildLineElementsForScreenRows: (startRow, endRow) ->
    div = document.createElement('div')
    div.innerHTML = @buildLinesHtml(@activeEditSession.linesForScreenRows(startRow, endRow))
    new Array(div.children...)

  buildLinesHtml: (screenLines) ->
    screenLines.map((line) => @buildLineHtml(line)).join('\n\n')

  buildLineHtml: (screenLine) ->
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
      if @activeEditSession.selectionIntersectsBufferRange(fold.getBufferRange())
        lineAttributes.class += ' selected'
    else
      lineAttributes = { class: 'line' }

    attributePairs = []
    attributePairs.push "#{attributeName}=\"#{value}\"" for attributeName, value of lineAttributes
    line.push("<pre #{attributePairs.join(' ')}>")

    invisibles = @invisibles if @showInvisibles

    if screenLine.text == ''
      line.push("&nbsp;") unless @showInvisibles
    else
      firstNonWhitespacePosition = screenLine.text.search(/\S/)
      firstTrailingWhitespacePosition = screenLine.text.search(/\s*$/)
      position = 0
      for token in screenLine.tokens
        updateScopeStack(token.scopes)
        line.push(token.getValueAsHtml(
          invisibles: invisibles
          hasLeadingWhitespace: position < firstNonWhitespacePosition
          hasTrailingWhitespace: position + token.value.length > firstTrailingWhitespacePosition
        ))

        position += token.value.length

    popScope() while scopeStack.length > 0
    if not @mini and invisibles?.eol
      line.push("<span class='invisible'>#{invisibles.eol}</span>")

    line.push('</pre>')
    line.join('')

  lineElementForScreenRow: (screenRow) ->
    @renderedLines.children(":eq(#{screenRow - @firstRenderedScreenRow})")

  logScreenLines: (start, end) ->
    @activeEditSession.logScreenLines(start, end)

  toggleLineCommentsInSelection: ->
    @activeEditSession.toggleLineCommentsInSelection()

  logRenderedLines: ->
    @renderedLines.find('.line').each (n) ->
      console.log n, $(this).text()

  pixelPositionForBufferPosition: (position) ->
    @pixelPositionForScreenPosition(@screenPositionForBufferPosition(position))

  pixelPositionForScreenPosition: (position) ->
    position = Point.fromObject(position)
    { top: position.row * @lineHeight, left: position.column * @charWidth }

  pixelOffsetForScreenPosition: (position) ->
    {top, left} = @pixelPositionForScreenPosition(position)
    offset = @renderedLines.offset()
    {top: top + offset.top, left: left + offset.left}

  screenPositionFromPixelPosition: ({top, left}) ->
    screenPosition = new Point(Math.floor(top / @lineHeight), Math.floor(left / @charWidth))

  screenPositionFromMouseEvent: (e) ->
    { pageX, pageY } = e
    @screenPositionFromPixelPosition
      top: pageY - @scrollView.offset().top + @scrollTop()
      left: pageX - @scrollView.offset().left + @scrollView.scrollLeft()

  highlightCursorLine: ->
    return if @mini

    @highlightedLine?.removeClass('cursor-line')
    if @getSelection().isEmpty()
      @highlightedLine = @lineElementForScreenRow(@getCursorScreenRow())
      @highlightedLine.addClass('cursor-line')
    else
      @highlightedLine = null

  getGrammar: -> @activeEditSession.getGrammar()

  selectGrammar: ->
    GrammarView = require 'grammar-view'
    new GrammarView(this)

  reloadGrammar: ->
    grammarChanged =  @activeEditSession.reloadGrammar()
    if grammarChanged
      @clearRenderedLines()
      @updateDisplay()
      @trigger 'editor:grammar-changed'
    grammarChanged

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
