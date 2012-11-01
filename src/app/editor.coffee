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
  @idCounter: 1

  @content: (params) ->
    @div class: @classes(params), tabindex: -1, =>
      @input class: 'hidden-input', outlet: 'hiddenInput'
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
  lineOverdraw: 100

  @deserialize: (state, rootView) ->
    editSessions = state.editSessions.map (state) -> EditSession.deserialize(state, rootView.project)
    editor = new Editor(editSession: editSessions[state.activeEditSessionIndex], mini: state.mini, showInvisibles: rootView.showInvisibles)
    editor.editSessions = editSessions
    editor.isFocused = state.isFocused
    editor

  initialize: ({editSession, @mini, @showInvisibles} = {}) ->
    requireStylesheet 'editor.css'

    @id = Editor.idCounter++
    @lineCache = []
    @bindKeys()
    @handleEvents()
    @cursorViews = []
    @selectionViews = []
    @editSessions = []

    if editSession?
      @editSessions.push editSession
      @setActiveEditSessionIndex(0)
    else if @mini
      editSession = new EditSession
        buffer: new Buffer()
        softWrap: false
        tabLength: 2
        autoIndent: false
        softTabs: true

      @editSessions.push editSession
      @setActiveEditSessionIndex(0)
    else
      throw new Error("Editor initialization requires an editSession")

  serialize: ->
    @saveActiveEditSession()

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
        'core:close': @close
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
        'editor:show-previous-buffer': @loadPreviousEditSession
        'editor:toggle-line-comments': @toggleLineCommentsInSelection
        'editor:log-cursor-scope': @logCursorScope

    documentation = {}
    for name, method of editorBindings
      do (name, method) =>
        @command name, => method.call(this); false

  getCursor: (index) -> @activeEditSession.getCursor(index)
  getCursors: -> @activeEditSession.getCursors()
  getLastCursor: -> @activeEditSession.getLastCursor()
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
  setCursorBufferPosition: (position, options) -> @activeEditSession.setCursorBufferPosition(position, options)
  getCursorBufferPosition: -> @activeEditSession.getCursorBufferPosition()

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
  clearSelections: -> @activeEditSession.clearSelections()

  backspace: -> @activeEditSession.backspace()
  backspaceToBeginningOfWord: -> @activeEditSession.backspaceToBeginningOfWord()
  delete: -> @activeEditSession.delete()
  deleteToEndOfWord: -> @activeEditSession.deleteToEndOfWord()
  deleteLine: -> @activeEditSession.deleteLine()
  cutToEndOfLine: -> @activeEditSession.cutToEndOfLine()
  insertText: (text, options) -> @activeEditSession.insertText(text, options)
  insertNewline: -> @activeEditSession.insertNewline()
  insertNewlineBelow: -> @activeEditSession.insertNewlineBelow()
  indent: -> @activeEditSession.indent()
  indentSelectedRows: -> @activeEditSession.indentSelectedRows()
  outdentSelectedRows: -> @activeEditSession.outdentSelectedRows()
  cutSelection: -> @activeEditSession.cutSelectedText()
  copySelection: -> @activeEditSession.copySelectedText()
  paste: -> @activeEditSession.pasteText()
  undo: -> @activeEditSession.undo()
  redo: -> @activeEditSession.redo()
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
  stateForScreenRow: (row) -> @activeEditSession.stateForScreenRow(row)

  logCursorScope: ->
    console.log @activeEditSession.tokenizedBuffer.scopesForPosition(@getCursorBufferPosition())

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
    @renderLines()

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
        @activeEditSession.selectWord() unless e.shiftKey
      else if clickCount == 3
        @activeEditSession.selectLine() unless e.shiftKey

      @selectOnMousemoveUntilMouseup()

    @on "textInput", (e) =>
      @insertText(e.originalEvent.data, autoIndent: true)
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

    unless @mini
      @gutter.widthChanged = (newWidth) =>
        @scrollView.css('left', newWidth + 'px')

    @scrollView.on 'scroll', =>
      if @scrollView.scrollLeft() == 0
        @gutter.removeClass('drop-shadow')
      else
        @gutter.addClass('drop-shadow')

    @on 'cursor-move', => @highlightCursorLine()
    @on 'selection-change', => @highlightCursorLine()

  selectOnMousemoveUntilMouseup: ->
    moveHandler = (e) => @selectToScreenPosition(@screenPositionFromMouseEvent(e))
    @on 'mousemove', moveHandler
    $(document).one 'mouseup', =>
      @off 'mousemove', moveHandler
      reverse = @activeEditSession.getLastSelection().isReversed()
      @activeEditSession.mergeIntersectingSelections({reverse})
      @activeEditSession.finalizeSelections()
      @syncCursorAnimations()

  afterAttach: (onDom) ->
    return if @attached or not onDom
    @attached = true
    @clearRenderedLines()
    @subscribeToFontSize()
    @calculateDimensions()
    @hiddenInput.width(@charWidth)
    @setSoftWrapColumn() if @activeEditSession.getSoftWrap()
    $(window).on "resize.editor#{@id}", =>
      @updateRenderedLines()
    @focus() if @isFocused

    @renderWhenAttached()

    @trigger 'editor-open', [this]

  edit: (editSession) ->
    index = @editSessions.indexOf(editSession)

    if index == -1
      index = @editSessions.length
      @editSessions.push(editSession)

    @setActiveEditSessionIndex(index)

  getBuffer: -> @activeEditSession.buffer

  destroyActiveEditSession: ->
    if @editSessions.length == 1
      @remove()
    else
      editSession = @activeEditSession
      @loadPreviousEditSession()
      _.remove(@editSessions, editSession)
      editSession.destroy()

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
      @saveActiveEditSession()
      @activeEditSession.off()

    @activeEditSession = @editSessions[index]

    @activeEditSession.on "buffer-contents-change-on-disk", =>
      @showBufferConflictAlert(@activeEditSession)

    @activeEditSession.on "buffer-path-change", =>
      @trigger 'editor-path-change'

    @activeEditSession.getSelection().on 'change-screen-range', =>
      @trigger 'selection-change'

    @trigger 'editor-path-change'
    @renderWhenAttached()

    if @attached and @activeEditSession.buffer.isInConflict()
      @showBufferConflictAlert(@activeEditSession)

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

  scrollTop: (scrollTop, options) ->
    return @cachedScrollTop or 0 unless scrollTop?

    maxScrollTop = @verticalScrollbar.prop('scrollHeight') - @verticalScrollbar.height()
    scrollTop = Math.floor(Math.max(0, Math.min(maxScrollTop, scrollTop)))
    return if scrollTop == @cachedScrollTop
    @cachedScrollTop = scrollTop

    @updateRenderedLines() if @attached

    @renderedLines.css('top', -scrollTop)
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

  scrollTo: (pixelPosition) ->
    return unless @attached
    @scrollVertically(pixelPosition)
    @scrollHorizontally(pixelPosition)

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

  saveActiveEditSession: ->
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
      $(window).on 'resize', @_setSoftWrapColumn
    else
      @removeClass 'soft-wrap'
      $(window).off 'resize', @_setSoftWrapColumn

  save: (onSuccess) ->
    if @getPath()
      @getBuffer().save()
      onSuccess?()
    else
      atom.showSaveDialog (path) =>
        if path
          @getBuffer().saveAs(path)
          onSuccess?()

  subscribeToFontSize: ->
    return unless rootView = @rootView()
    @setFontSize(rootView.getFontSize())
    rootView.on "font-size-change.editor#{@id}", => @setFontSize(rootView.getFontSize())

  setFontSize: (fontSize) ->
    if fontSize?
      @css('font-size', fontSize + 'px')
      @calculateDimensions()
      @updateCursorViews()
      @updateRenderedLines()

  newSplitEditor: ->
    new Editor { editSession: @activeEditSession.copy(), @showInvisibles }

  splitLeft: ->
    @pane()?.splitLeft(@newSplitEditor()).wrappedView

  splitRight: ->
    @pane()?.splitRight(@newSplitEditor()).wrappedView

  splitUp: ->
    @pane()?.splitUp(@newSplitEditor()).wrappedView

  splitDown: ->
    @pane()?.splitDown(@newSplitEditor()).wrappedView

  pane: ->
    @parent('.pane').view()

  rootView: ->
    @parents('#root-view').view()

  close: ->
    return if @mini
    if @getBuffer().isModified()
      filename = if @getPath() then fs.base(@getPath()) else "untitled buffer"
      atom.confirm(
        "'#{filename}' has changes, do you want to save them?"
        "Your changes will be lost if you don't save them"
        "Save", (=> @save(=> @destroyActiveEditSession())),
        "Cancel", null
        "Don't save", (=> @destroyActiveEditSession())
      )
    else
      @destroyActiveEditSession()

  remove: (selector, keepData) ->
    return super if keepData

    @trigger 'before-remove'

    @destroyEditSessions()

    $(window).off ".editor#{@id}"
    rootView = @rootView()
    rootView?.off ".editor#{@id}"
    if @pane() then @pane().remove() else super
    rootView?.focus()

  getEditSessions: ->
    new Array(@editSessions...)

  destroyEditSessions: ->
    for session in @getEditSessions()
      session.destroy()

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
    @activeEditSession.on 'screen-lines-change', (e) => @handleDisplayBufferChange(e)

  getCursorView: (index) ->
    index ?= @cursorViews.length - 1
    @cursorViews[index]

  getCursorViews: ->
    new Array(@cursorViews...)

  addCursorView: (cursor) ->
    cursorView = new CursorView(cursor, this)
    @cursorViews.push(cursorView)
    @appendToLinesView(cursorView)
    cursorView

  removeCursorView: (cursorView) ->
    _.remove(@cursorViews, cursorView)

  updateCursorViews: ->
    for cursorView in @getCursorViews()
      cursorView.updateAppearance()

  syncCursorAnimations: ->
    for cursorView in @getCursorViews()
      do (cursorView) -> cursorView.resetCursorAnimation()

  getSelectionView: (index) ->
    index ?= @selectionViews.length - 1
    @selectionViews[index]

  getSelectionViews: ->
    new Array(@selectionViews...)

  addSelectionView: (selection) ->
    selectionView = new SelectionView({editor: this, selection})
    @selectionViews.push(selectionView)
    @appendToLinesView(selectionView)
    selectionView

  removeSelectionView: (selectionView) ->
    _.remove(@selectionViews, selectionView)

  removeAllCursorAndSelectionViews: ->
    cursorView.remove() for cursorView in @getCursorViews()
    selectionView.remove() for selectionView in @getSelectionViews()

  appendToLinesView: (view) ->
    @renderedLines.append(view)

  calculateDimensions: ->
    fragment = $('<pre class="line" style="position: absolute; visibility: hidden;"><span>x</span></div>')
    @appendToLinesView(fragment)

    lineRect = fragment[0].getBoundingClientRect()
    charRect = fragment.find('span')[0].getBoundingClientRect()
    @lineHeight = lineRect.height
    @charWidth = charRect.width
    @charHeight = charRect.height
    @height(@lineHeight) if @mini
    fragment.remove()

    @gutter.calculateWidth()

  prepareForScrolling: ->
    @adjustHeightOfRenderedLines()
    @adjustMinWidthOfRenderedLines()

  adjustHeightOfRenderedLines: ->
    heightOfRenderedLines = @lineHeight * @screenLineCount()
    @verticalScrollbarContent.height(heightOfRenderedLines)
    @renderedLines.css('padding-bottom', heightOfRenderedLines)

  adjustMinWidthOfRenderedLines: ->
    minWidth = @charWidth * @maxScreenLineLength()
    unless @renderedLines.cachedMinWidth == minWidth
      @renderedLines.css('min-width', minWidth)
      @renderedLines.cachedMinWidth = minWidth

  handleScrollHeightChange: ->
    scrollHeight = @lineHeight * @screenLineCount()
    @verticalScrollbarContent.height(scrollHeight)
    @scrollBottom(scrollHeight) if @scrollBottom() > scrollHeight

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
      @highlightCursorLine()
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

  handleDisplayBufferChange: (e) ->
    oldScreenRange = e.oldRange
    newScreenRange = e.newRange

    if @attached
      @handleScrollHeightChange() unless newScreenRange.coversSameRows(oldScreenRange)
      @adjustMinWidthOfRenderedLines()

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

      oldScreenRange.start.row = Math.max(oldScreenRange.start.row, @firstRenderedScreenRow)
      oldScreenRange.end.row = Math.min(oldScreenRange.end.row, @lastRenderedScreenRow)
      newScreenRange.start.row = Math.max(newScreenRange.start.row, @firstRenderedScreenRow)
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
    lines = @activeEditSession.linesForScreenRows(startRow, endRow)
    activeEditSession = @activeEditSession
    cursorScreenRow = @getCursorScreenPosition().row
    mini = @mini

    buildLineHtml = (line, lineClasses) => @buildLineHtml(line, lineClasses)

    $$ ->
      row = startRow
      for line in lines
        if mini or row isnt cursorScreenRow
          lineClasses = null
        else
          lineClasses = ' cursor-line'
        @raw(buildLineHtml(line, lineClasses))
        row++

  buildLineHtml: (screenLine, lineClasses) ->
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

    lineAttributes.class += lineClasses if lineClasses

    attributePairs = []
    attributePairs.push "#{attributeName}=\"#{value}\"" for attributeName, value of lineAttributes
    line.push("<pre #{attributePairs.join(' ')}>")

    if screenLine.text == ''
      line.push("&nbsp;") unless @showInvisibles
    else
      firstNonWhitespacePosition = screenLine.text.search(/\S/)
      firstTrailingWhitespacePosition = screenLine.text.search(/\s*$/)
      position = 0
      for token in screenLine.tokens
        updateScopeStack(token.scopes)
        line.push(token.getValueAsHtml(
          showInvisibles: @showInvisibles
          hasLeadingWhitespace: position < firstNonWhitespacePosition
          hasTrailingWhitespace: position + token.value.length > firstTrailingWhitespacePosition
        ))

        position += token.value.length

    popScope() while scopeStack.length > 0
    line.push("<span class='invisible'>¬</span>") if @showInvisibles
    line.push('</pre>')
    line.join('')

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

  logScreenLines: (start, end) ->
    @activeEditSession.logScreenLines(start, end)

  toggleLineCommentsInSelection: ->
    @activeEditSession.toggleLineCommentsInSelection()

  logRenderedLines: ->
    @renderedLines.find('.line').each (n) ->
      console.log n, $(this).text()

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

    @cursorScreenRow = @getCursorScreenPosition().row
    screenRow = @cursorScreenRow - @firstRenderedScreenRow
    @find('pre.line.cursor-line').removeClass('cursor-line')
    if @getSelection().isSingleScreenLine()
      @find("pre.line:eq(#{screenRow})").addClass('cursor-line')
