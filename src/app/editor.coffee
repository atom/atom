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

# Public: Represents the entire visual pane in Atom.
#
# The Editor manages the {EditSession}, which manages the file buffers.
module.exports =
class Editor extends View
  @configDefaults:
    fontSize: 20
    showInvisibles: false
    showIndentGuide: false
    showLineNumbers: true
    autoIndent: true
    autoIndentOnPaste: false
    normalizeIndentOnPaste: false
    nonWordCharacters: "./\\()\"':,.;<>~!@#$%^&*|+=[]{}`~?-"
    preferredLineLength: 80

  @nextEditorId: 1

  ### Internal ###

  @content: (params) ->
    attributes = { class: @classes(params), tabindex: -1 }
    _.extend(attributes, params.attributes) if params.attributes
    @div attributes, =>
      @subview 'gutter', new Gutter
      @input class: 'hidden-input', outlet: 'hiddenInput'
      @div class: 'scroll-view', outlet: 'scrollView', =>
        @div class: 'overlayer', outlet: 'overlayer'
        @div class: 'lines', outlet: 'renderedLines'
        @div class: 'underlayer', outlet: 'underlayer'
      @div class: 'vertical-scrollbar', outlet: 'verticalScrollbar', =>
        @div outlet: 'verticalScrollbarContent'

  @classes: ({mini} = {}) ->
    classes = ['editor', 'editor-colors']
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
  bottomPaddingInLines: 10

  ### Public ###

  # The constructor for setting up an `Editor` instance.
  #
  # editSessionOrOptions - Either an {EditSession}, or an object with one property, `mini`.
  #                        If `mini` is `true`, a "miniature" `EditSession` is constructed.
  #                        Typically, this is ideal for scenarios where you need an Atom editor,
  #                        but without all the chrome, like scrollbars, gutter, _e.t.c._.
  #
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

  # Internal: Sets up the core Atom commands.
  #
  # Some commands are excluded from mini-editors.
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
        'editor:scroll-to-cursor': @scrollToCursorPosition

    documentation = {}
    for name, method of editorBindings
      do (name, method) =>
        @command name, (e) => method.call(this, e); false

  # {Delegates to: EditSession.getCursor}
  getCursor: -> @activeEditSession.getCursor()

  # {Delegates to: EditSession.getCursors}
  getCursors: -> @activeEditSession.getCursors()

  # {Delegates to: EditSession.addCursorAtScreenPosition}
  addCursorAtScreenPosition: (screenPosition) -> @activeEditSession.addCursorAtScreenPosition(screenPosition)

  # {Delegates to: EditSession.addCursorAtBufferPosition}
  addCursorAtBufferPosition: (bufferPosition) -> @activeEditSession.addCursorAtBufferPosition(bufferPosition)

  # {Delegates to: EditSession.moveCursorUp}
  moveCursorUp: -> @activeEditSession.moveCursorUp()

  # {Delegates to: EditSession.moveCursorDown}
  moveCursorDown: -> @activeEditSession.moveCursorDown()

  # {Delegates to: EditSession.moveCursorLeft}
  moveCursorLeft: -> @activeEditSession.moveCursorLeft()

  # {Delegates to: EditSession.moveCursorRight}
  moveCursorRight: -> @activeEditSession.moveCursorRight()

  # {Delegates to: EditSession.moveCursorToBeginningOfWord}
  moveCursorToBeginningOfWord: -> @activeEditSession.moveCursorToBeginningOfWord()

  # {Delegates to: EditSession.moveCursorToEndOfWord}
  moveCursorToEndOfWord: -> @activeEditSession.moveCursorToEndOfWord()

  # {Delegates to: EditSession.moveCursorToBeginningOfNextWord}
  moveCursorToBeginningOfNextWord: -> @activeEditSession.moveCursorToBeginningOfNextWord()

  # {Delegates to: EditSession.moveCursorToTop}
  moveCursorToTop: -> @activeEditSession.moveCursorToTop()

  # {Delegates to: EditSession.moveCursorToBottom}
  moveCursorToBottom: -> @activeEditSession.moveCursorToBottom()

  # {Delegates to: EditSession.moveCursorToBeginningOfLine}
  moveCursorToBeginningOfLine: -> @activeEditSession.moveCursorToBeginningOfLine()

  # {Delegates to: EditSession.moveCursorToFirstCharacterOfLine}
  moveCursorToFirstCharacterOfLine: -> @activeEditSession.moveCursorToFirstCharacterOfLine()

  # {Delegates to: EditSession.moveCursorToEndOfLine}
  moveCursorToEndOfLine: -> @activeEditSession.moveCursorToEndOfLine()

  # {Delegates to: EditSession.moveLineUp}
  moveLineUp: -> @activeEditSession.moveLineUp()

  # {Delegates to: EditSession.moveLineDown}
  moveLineDown: -> @activeEditSession.moveLineDown()

  # {Delegates to: EditSession.setCursorScreenPosition}
  setCursorScreenPosition: (position, options) -> @activeEditSession.setCursorScreenPosition(position, options)

  # {Delegates to: EditSession.duplicateLine}
  duplicateLine: -> @activeEditSession.duplicateLine()

  # {Delegates to: EditSession.joinLine}
  joinLine: -> @activeEditSession.joinLine()

  # {Delegates to: EditSession.getCursorScreenPosition}
  getCursorScreenPosition: -> @activeEditSession.getCursorScreenPosition()

  # {Delegates to: EditSession.getCursorScreenRow}
  getCursorScreenRow: -> @activeEditSession.getCursorScreenRow()

  # {Delegates to: EditSession.setCursorBufferPosition}
  setCursorBufferPosition: (position, options) -> @activeEditSession.setCursorBufferPosition(position, options)

  # {Delegates to: EditSession.getCursorBufferPosition}
  getCursorBufferPosition: -> @activeEditSession.getCursorBufferPosition()

  # {Delegates to: EditSession.getCurrentParagraphBufferRange}
  getCurrentParagraphBufferRange: -> @activeEditSession.getCurrentParagraphBufferRange()

  # {Delegates to: EditSession.getWordUnderCursor}
  getWordUnderCursor: (options) -> @activeEditSession.getWordUnderCursor(options)

  # {Delegates to: EditSession.getSelection}
  getSelection: (index) -> @activeEditSession.getSelection(index)

  # {Delegates to: EditSession.getSelections}
  getSelections: -> @activeEditSession.getSelections()

  # {Delegates to: EditSession.getSelectionsOrderedByBufferPosition}
  getSelectionsOrderedByBufferPosition: -> @activeEditSession.getSelectionsOrderedByBufferPosition()

  # {Delegates to: EditSession.getLastSelectionInBuffer}
  getLastSelectionInBuffer: -> @activeEditSession.getLastSelectionInBuffer()

  # {Delegates to: EditSession.getSelectedText}
  getSelectedText: -> @activeEditSession.getSelectedText()

  # {Delegates to: EditSession.getSelectedBufferRanges}
  getSelectedBufferRanges: -> @activeEditSession.getSelectedBufferRanges()

  # {Delegates to: EditSession.getSelectedBufferRange}
  getSelectedBufferRange: -> @activeEditSession.getSelectedBufferRange()

  # {Delegates to: EditSession.setSelectedBufferRange}
  setSelectedBufferRange: (bufferRange, options) -> @activeEditSession.setSelectedBufferRange(bufferRange, options)

  # {Delegates to: EditSession.setSelectedBufferRanges}
  setSelectedBufferRanges: (bufferRanges, options) -> @activeEditSession.setSelectedBufferRanges(bufferRanges, options)

  # {Delegates to: EditSession.addSelectionForBufferRange}
  addSelectionForBufferRange: (bufferRange, options) -> @activeEditSession.addSelectionForBufferRange(bufferRange, options)

  # {Delegates to: EditSession.selectRight}
  selectRight: -> @activeEditSession.selectRight()

  # {Delegates to: EditSession.selectLeft}
  selectLeft: -> @activeEditSession.selectLeft()

  # {Delegates to: EditSession.selectUp}
  selectUp: -> @activeEditSession.selectUp()

  # {Delegates to: EditSession.selectDown}
  selectDown: -> @activeEditSession.selectDown()

  # {Delegates to: EditSession.selectToTop}
  selectToTop: -> @activeEditSession.selectToTop()

  # {Delegates to: EditSession.selectToBottom}
  selectToBottom: -> @activeEditSession.selectToBottom()

  # {Delegates to: EditSession.selectAll}
  selectAll: -> @activeEditSession.selectAll()

  # {Delegates to: EditSession.selectToBeginningOfLine}
  selectToBeginningOfLine: -> @activeEditSession.selectToBeginningOfLine()

  # {Delegates to: EditSession.selectToEndOfLine}
  selectToEndOfLine: -> @activeEditSession.selectToEndOfLine()

  # {Delegates to: EditSession.addSelectionBelow}
  addSelectionBelow: -> @activeEditSession.addSelectionBelow()

  # {Delegates to: EditSession.addSelectionAbove}
  addSelectionAbove: -> @activeEditSession.addSelectionAbove()

  # {Delegates to: EditSession.selectToBeginningOfWord}
  selectToBeginningOfWord: -> @activeEditSession.selectToBeginningOfWord()

  # {Delegates to: EditSession.selectToEndOfWord}
  selectToEndOfWord: -> @activeEditSession.selectToEndOfWord()

  # {Delegates to: EditSession.selectToBeginningOfNextWord}
  selectToBeginningOfNextWord: -> @activeEditSession.selectToBeginningOfNextWord()

  # {Delegates to: EditSession.selectWord}
  selectWord: -> @activeEditSession.selectWord()

  # {Delegates to: EditSession.selectLine}
  selectLine: -> @activeEditSession.selectLine()

  # {Delegates to: EditSession.selectToScreenPosition}
  selectToScreenPosition: (position) -> @activeEditSession.selectToScreenPosition(position)

  # {Delegates to: EditSession.transpose}
  transpose: -> @activeEditSession.transpose()

  # {Delegates to: EditSession.upperCase}
  upperCase: -> @activeEditSession.upperCase()

  # {Delegates to: EditSession.lowerCase}
  lowerCase: -> @activeEditSession.lowerCase()

  # {Delegates to: EditSession.clearSelections}
  clearSelections: -> @activeEditSession.clearSelections()

  # {Delegates to: EditSession.backspace}
  backspace: -> @activeEditSession.backspace()

  # {Delegates to: EditSession.backspaceToBeginningOfWord}
  backspaceToBeginningOfWord: -> @activeEditSession.backspaceToBeginningOfWord()

  # {Delegates to: EditSession.backspaceToBeginningOfLine}
  backspaceToBeginningOfLine: -> @activeEditSession.backspaceToBeginningOfLine()

  # {Delegates to: EditSession.delete}
  delete: -> @activeEditSession.delete()

  # {Delegates to: EditSession.deleteToEndOfWord}
  deleteToEndOfWord: -> @activeEditSession.deleteToEndOfWord()

  # {Delegates to: EditSession.deleteLine}
  deleteLine: -> @activeEditSession.deleteLine()

  # {Delegates to: EditSession.cutToEndOfLine}
  cutToEndOfLine: -> @activeEditSession.cutToEndOfLine()

  # {Delegates to: EditSession.insertText}
  insertText: (text, options) -> @activeEditSession.insertText(text, options)

  # {Delegates to: EditSession.insertNewline}
  insertNewline: -> @activeEditSession.insertNewline()

  # {Delegates to: EditSession.insertNewlineBelow}
  insertNewlineBelow: -> @activeEditSession.insertNewlineBelow()

  # {Delegates to: EditSession.insertNewlineAbove}
  insertNewlineAbove: -> @activeEditSession.insertNewlineAbove()

  # {Delegates to: EditSession.indent}
  indent: (options) -> @activeEditSession.indent(options)

  # {Delegates to: EditSession.autoIndentSelectedRows}
  autoIndent: (options) -> @activeEditSession.autoIndentSelectedRows()

  # {Delegates to: EditSession.indentSelectedRows}
  indentSelectedRows: -> @activeEditSession.indentSelectedRows()

  # {Delegates to: EditSession.outdentSelectedRows}
  outdentSelectedRows: -> @activeEditSession.outdentSelectedRows()

  # {Delegates to: EditSession.cutSelectedText}
  cutSelection: -> @activeEditSession.cutSelectedText()

  # {Delegates to: EditSession.copySelectedText}
  copySelection: -> @activeEditSession.copySelectedText()

  # {Delegates to: EditSession.pasteText}
  paste: (options) -> @activeEditSession.pasteText(options)

  # {Delegates to: EditSession.undo}
  undo: -> @activeEditSession.undo()

  # {Delegates to: EditSession.redo}
  redo: -> @activeEditSession.redo()

  # {Delegates to: EditSession.createFold}
  createFold: (startRow, endRow) -> @activeEditSession.createFold(startRow, endRow)

  # {Delegates to: EditSession.foldCurrentRow}
  foldCurrentRow: -> @activeEditSession.foldCurrentRow()

  # {Delegates to: EditSession.unfoldCurrentRow}
  unfoldCurrentRow: -> @activeEditSession.unfoldCurrentRow()

  # {Delegates to: EditSession.foldAll}
  foldAll: -> @activeEditSession.foldAll()

  # {Delegates to: EditSession.unfoldAll}
  unfoldAll: -> @activeEditSession.unfoldAll()

  # {Delegates to: EditSession.foldSelection}
  foldSelection: -> @activeEditSession.foldSelection()

  # {Delegates to: EditSession.destroyFoldsContainingBufferRow}
  destroyFoldsContainingBufferRow: (bufferRow) -> @activeEditSession.destroyFoldsContainingBufferRow(bufferRow)

  # {Delegates to: EditSession.isFoldedAtScreenRow}
  isFoldedAtScreenRow: (screenRow) -> @activeEditSession.isFoldedAtScreenRow(screenRow)

  # {Delegates to: EditSession.isFoldedAtBufferRow}
  isFoldedAtBufferRow: (bufferRow) -> @activeEditSession.isFoldedAtBufferRow(bufferRow)

  # {Delegates to: EditSession.isFoldedAtCursorRow}
  isFoldedAtCursorRow: -> @activeEditSession.isFoldedAtCursorRow()

  # {Delegates to: EditSession.lineForScreenRow}
  lineForScreenRow: (screenRow) -> @activeEditSession.lineForScreenRow(screenRow)

  # {Delegates to: EditSession.linesForScreenRows}
  linesForScreenRows: (start, end) -> @activeEditSession.linesForScreenRows(start, end)

  # {Delegates to: EditSession.getScreenLineCount}
  getScreenLineCount: -> @activeEditSession.getScreenLineCount()

  # {Delegates to: EditSession.setSoftWrapColumn}
  setSoftWrapColumn: (softWrapColumn) ->
    softWrapColumn ?= @calcSoftWrapColumn()
    @activeEditSession.setSoftWrapColumn(softWrapColumn) if softWrapColumn

  # {Delegates to: EditSession.getMaxScreenLineLength}
  getMaxScreenLineLength: -> @activeEditSession.getMaxScreenLineLength()

  # {Delegates to: EditSession.getLastScreenRow}
  getLastScreenRow: -> @activeEditSession.getLastScreenRow()

  # {Delegates to: EditSession.clipScreenPosition}
  clipScreenPosition: (screenPosition, options={}) -> @activeEditSession.clipScreenPosition(screenPosition, options)

  # {Delegates to: EditSession.screenPositionForBufferPosition}
  screenPositionForBufferPosition: (position, options) -> @activeEditSession.screenPositionForBufferPosition(position, options)

  # {Delegates to: EditSession.bufferPositionForScreenPosition}
  bufferPositionForScreenPosition: (position, options) -> @activeEditSession.bufferPositionForScreenPosition(position, options)

  # {Delegates to: EditSession.screenRangeForBufferRange}
  screenRangeForBufferRange: (range) -> @activeEditSession.screenRangeForBufferRange(range)

  # {Delegates to: EditSession.bufferRangeForScreenRange}
  bufferRangeForScreenRange: (range) -> @activeEditSession.bufferRangeForScreenRange(range)

  # {Delegates to: EditSession.bufferRowsForScreenRows}
  bufferRowsForScreenRows: (startRow, endRow) -> @activeEditSession.bufferRowsForScreenRows(startRow, endRow)

  # Public: Emulates the "page down" key, where the last row of a buffer scrolls to become the first.
  pageDown: ->
    newScrollTop = @scrollTop() + @scrollView[0].clientHeight
    @activeEditSession.moveCursorDown(@getPageRows())
    @scrollTop(newScrollTop,  adjustVerticalScrollbar: true)

  # Public: Emulates the "page up" key, where the frst row of a buffer scrolls to become the last.
  pageUp: ->
    newScrollTop = @scrollTop() - @scrollView[0].clientHeight
    @activeEditSession.moveCursorUp(@getPageRows())
    @scrollTop(newScrollTop,  adjustVerticalScrollbar: true)

  # Gets the number of actual page rows existing in an editor.
  #
  # Returns a {Number}.
  getPageRows: ->
    Math.max(1, Math.ceil(@scrollView[0].clientHeight / @lineHeight))

  # Set whether invisible characters are shown.
  #
  # showInvisibles - A {Boolean} which, if `true`, show invisible characters
  setShowInvisibles: (showInvisibles) ->
    return if showInvisibles == @showInvisibles
    @showInvisibles = showInvisibles
    @resetDisplay()

  # Defines which characters are invisible.
  #
  # invisibles - A hash defining the invisible characters: The defaults are:
  #              eol: `\u00ac`
  #              space: `\u00b7`
  #              tab: `\u00bb`
  #              cr: `\u00a4`
  setInvisibles: (@invisibles={}) ->
    _.defaults @invisibles,
      eol: '\u00ac'
      space: '\u00b7'
      tab: '\u00bb'
      cr: '\u00a4'
    @resetDisplay()

  # Sets whether you want to show the indentation guides.
  #
  # showIndentGuide - A {Boolean} you can set to `true` if you want to see the indentation guides.
  setShowIndentGuide: (showIndentGuide) ->
    return if showIndentGuide == @showIndentGuide
    @showIndentGuide = showIndentGuide
    @resetDisplay()

  # {Delegates to: Buffer.checkoutHead}
  checkoutHead: -> @getBuffer().checkoutHead()

  # {Delegates to: EditSession.setText}
  setText: (text) -> @activeEditSession.setText(text)

  # {Delegates to: EditSession.getText}
  getText: -> @activeEditSession.getText()

  # {Delegates to: EditSession.getPath}
  getPath: -> @activeEditSession?.getPath()

  #  {Delegates to: Buffer.getLineCount}
  getLineCount: -> @getBuffer().getLineCount()

  #  {Delegates to: Buffer.getLastRow}
  getLastBufferRow: -> @getBuffer().getLastRow()

  #  {Delegates to: Buffer.getTextInRange}
  getTextInRange: (range) -> @getBuffer().getTextInRange(range)

  #  {Delegates to: Buffer.getEofPosition}
  getEofPosition: -> @getBuffer().getEofPosition()

  #  {Delegates to: Buffer.lineForRow}
  lineForBufferRow: (row) -> @getBuffer().lineForRow(row)

  #  {Delegates to: Buffer.lineLengthForRow}
  lineLengthForBufferRow: (row) -> @getBuffer().lineLengthForRow(row)

  #  {Delegates to: Buffer.rangeForRow}
  rangeForBufferRow: (row) -> @getBuffer().rangeForRow(row)

  #  {Delegates to: Buffer.scanInRange}
  scanInBufferRange: (args...) -> @getBuffer().scanInRange(args...)

  #  {Delegates to: Buffer.backwardsScanInRange}
  backwardsScanInBufferRange: (args...) -> @getBuffer().backwardsScanInRange(args...)

  ### Internal ###

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

    @underlayer.on 'mousedown', (e) =>
      @renderedLines.trigger(e)
      false if @isFocused

    @overlayer.on 'mousedown', (e) =>
      @overlayer.hide()
      clickedElement = document.elementFromPoint(e.pageX, e.pageY)
      @overlayer.show()
      e.target = clickedElement
      $(clickedElement).trigger(e)
      false if @isFocused

    @renderedLines.on 'mousedown', '.fold.line', (e) =>
      @activeEditSession.destroyFoldWithId($(e.currentTarget).attr('fold-id'))
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

      @selectOnMousemoveUntilMouseup() unless e.ctrlKey or e.originalEvent.which > 1

    @on "textInput", (e) =>
      @insertText(e.originalEvent.data)
      false

    @scrollView.on 'mousewheel', (e) =>
      if delta = e.originalEvent.wheelDeltaY
        @scrollTop(@scrollTop() - delta)
        false

    @verticalScrollbar.on 'scroll', =>
      @scrollTop(@verticalScrollbar.scrollTop(), adjustVerticalScrollbar: false)

    @scrollView.on 'scroll', =>
      if @scrollLeft() == 0
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
    @setSoftWrapColumn() if @activeEditSession.getSoftWrap()
    @subscribe $(window), "resize.editor-#{@id}", => @requestDisplayUpdate()
    @focus() if @isFocused

    if pane = @getPane()
      @active = @is(pane.activeView)
      @subscribe pane, 'pane:active-item-changed', (event, item) =>
        wasActive = @active
        @active = @is(pane.activeView)
        @redraw() if @active and not wasActive

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

    @activeEditSession.on 'selection-added.editor', (selection) =>
      @newCursors.push(selection.cursor)
      @newSelections.push(selection)
      @requestDisplayUpdate()

    @activeEditSession.on 'screen-lines-changed.editor', (e) =>
      @handleScreenLinesChange(e)

    @trigger 'editor:path-changed'
    @resetDisplay()

    if @attached and @activeEditSession.buffer.isInConflict()
      _.defer => @showBufferConflictAlert(@activeEditSession) # Display after editSession has a chance to display

  getModel: ->
    @activeEditSession

  setModel: (editSession) ->
    @edit(editSession)

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
    @activeEditSession.setScrollTop(@scrollTop())

  scrollBottom: (scrollBottom) ->
    if scrollBottom?
      @scrollTop(scrollBottom - @scrollView.height())
    else
      @scrollTop() + @scrollView.height()

  scrollLeft: (scrollLeft) ->
    if scrollLeft?
      @scrollView.scrollLeft(scrollLeft)
      @activeEditSession.setScrollLeft(@scrollLeft())
    else
      @scrollView.scrollLeft()

  scrollRight: (scrollRight) ->
    if scrollRight?
      @scrollView.scrollRight(scrollRight)
      @activeEditSession.setScrollLeft(@scrollLeft())
    else
      @scrollView.scrollRight()

  ### Public ###

  # Retrieves the {EditSession}'s buffer.
  #
  # Returns the current {Buffer}.
  getBuffer: -> @activeEditSession.buffer

  # Scrolls the editor to the bottom.
  scrollToBottom: ->
    @scrollBottom(@getScreenLineCount() * @lineHeight)

  # Scrolls the editor to the position of the most recently added cursor.
  #
  # The editor is also centered.
  scrollToCursorPosition: ->
    @scrollToBufferPosition(@getCursorBufferPosition(), center: true)

  # Scrolls the editor to the given buffer position.
  #
  # bufferPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash matching the options available to {.scrollToPixelPosition}
  scrollToBufferPosition: (bufferPosition, options) ->
    @scrollToPixelPosition(@pixelPositionForBufferPosition(bufferPosition), options)

  # Scrolls the editor to the given screen position.
  #
  # screenPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash matching the options available to {.scrollToPixelPosition}
  scrollToScreenPosition: (screenPosition, options) ->
    @scrollToPixelPosition(@pixelPositionForScreenPosition(screenPosition), options)

  # Scrolls the editor to the given pixel position.
  #
  # pixelPosition - An object that represents a pixel position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash with the following keys:
  #          center: if `true`, the position is scrolled such that it's in the center of the editor
  scrollToPixelPosition: (pixelPosition, options) ->
    return unless @attached
    @scrollVertically(pixelPosition, options)
    @scrollHorizontally(pixelPosition)

  # Given a buffer range, this highlights all the folds within that range
  #
  # "Highlighting" essentially just adds the `selected` class to the line
  #
  # bufferRange - The {Range} to check
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

  saveScrollPositionForActiveEditSession: ->
    if @attached
      @activeEditSession.setScrollTop(@scrollTop())
      @activeEditSession.setScrollLeft(@scrollLeft())

  # {Delegates to: EditSession.setSoftTabs}
  toggleSoftTabs: ->
    @activeEditSession.setSoftTabs(not @activeEditSession.softTabs)

  # Activates soft wraps in the editor.
  toggleSoftWrap: ->
    @setSoftWrap(not @activeEditSession.getSoftWrap())

  calcSoftWrapColumn: ->
    if @activeEditSession.getSoftWrap()
      Math.floor(@scrollView.width() / @charWidth)
    else
      Infinity

  # Sets the soft wrap column for the editor.
  #
  # softWrap - A {Boolean} which, if `true`, sets soft wraps
  # softWrapColumn - A {Number} indicating the length of a line in the editor when soft
  # wrapping turns on
  setSoftWrap: (softWrap, softWrapColumn=undefined) ->
    @activeEditSession.setSoftWrap(softWrap)
    @setSoftWrapColumn(softWrapColumn) if @attached
    if @activeEditSession.getSoftWrap()
      @addClass 'soft-wrap'
      @scrollLeft(0)
      @_setSoftWrapColumn = => @setSoftWrapColumn()
      $(window).on "resize.editor-#{@id}", @_setSoftWrapColumn
    else
      @removeClass 'soft-wrap'
      $(window).off 'resize', @_setSoftWrapColumn

  # Sets the font size for the editor.
  #
  # fontSize - A {Number} indicating the font size in pixels.
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

  # Retrieves the font size for the editor.
  #
  # Returns a {Number} indicating the font size in pixels.
  getFontSize: ->
    parseInt(@css("font-size"))

  # Sets the font family for the editor.
  #
  # fontFamily - A {String} identifying the CSS `font-family`,
  setFontFamily: (fontFamily) ->
    headTag = $("head")
    styleTag = headTag.find("style.editor-font-family")

    if fontFamily?
      if styleTag.length == 0
        styleTag = $$ -> @style class: 'editor-font-family'
        headTag.append styleTag
      styleTag.text(".editor {font-family: #{fontFamily}}")
    else
      styleTag.remove()

    @redraw()

  # Gets the font family for the editor.
  #
  # Returns a {String} identifying the CSS `font-family`,
  getFontFamily: -> @css("font-family")

  # Clears the CSS `font-family` property from the editor.
  clearFontFamily: ->
    $('head style.editor-font-family').remove()

  # Clears the CSS `font-family` property from the editor.
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

  # Retrieve's the `Editor`'s pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parent('.item-views').parent('.pane').view()

  remove: (selector, keepData) ->
    return super if keepData or @removed
    super
    rootView?.focus()

  beforeRemove: ->
    @trigger 'editor:will-be-removed'
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

  ### Internal ###

  # Scrolls the editor vertically to a given position.
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

  # Scrolls the editor horizontally to a given position.
  scrollHorizontally: (pixelPosition) ->
    return if @activeEditSession.getSoftWrap()

    charsInView = @scrollView.width() / @charWidth
    maxScrollMargin = Math.floor((charsInView - 1) / 2)
    scrollMargin = Math.min(@hScrollMargin, maxScrollMargin)
    margin = scrollMargin * @charWidth
    desiredRight = pixelPosition.left + @charWidth + margin
    desiredLeft = pixelPosition.left - margin

    if desiredRight > @scrollRight()
      @scrollRight(desiredRight)
    else if desiredLeft < @scrollLeft()
      @scrollLeft(desiredLeft)
    @saveScrollPositionForActiveEditSession()

  calculateDimensions: ->
    fragment = $('<div class="line" style="position: absolute; visibility: hidden;"><span>x</span></div>')
    @renderedLines.append(fragment)

    lineRect = fragment[0].getBoundingClientRect()
    charRect = fragment.find('span')[0].getBoundingClientRect()
    @lineHeight = lineRect.height
    @charWidth = charRect.width
    @charHeight = charRect.height
    fragment.remove()

  updateLayerDimensions: ->
    height = @lineHeight * @getScreenLineCount()
    unless @layerHeight == height
      @layerHeight = height
      @underlayer.height(@layerHeight)
      @renderedLines.height(@layerHeight)
      @overlayer.height(@layerHeight)
      @verticalScrollbarContent.height(@layerHeight)
      @scrollBottom(height) if @scrollBottom() > height

    minWidth = @charWidth * @getMaxScreenLineLength() + 20
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
    editSessionScrollTop = @activeEditSession.scrollTop ? 0
    editSessionScrollLeft = @activeEditSession.scrollLeft ? 0
    @updateLayerDimensions()
    @scrollTop(editSessionScrollTop)
    @scrollLeft(editSessionScrollLeft)
    @newCursors = @activeEditSession.getCursors()
    @newSelections = @activeEditSession.getSelections()
    @updateDisplay(suppressAutoScroll: true)

  requestDisplayUpdate: ->
    return if @pendingDisplayUpdate
    return unless @isVisible()
    @pendingDisplayUpdate = true
    _.nextTick =>
      @updateDisplay()
      @pendingDisplayUpdate = false

  updateDisplay: (options={}) ->
    return unless @attached and @activeEditSession
    return if @activeEditSession.destroyed
    unless @isVisible()
      @redrawOnReattach = true
      return

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
    lastScreenRow = @getLastScreenRow()

    if @firstRenderedScreenRow? and firstVisibleScreenRow >= @firstRenderedScreenRow and lastVisibleScreenRow <= @lastRenderedScreenRow
      renderFrom = Math.min(lastScreenRow, @firstRenderedScreenRow)
      renderTo = Math.min(lastScreenRow, @lastRenderedScreenRow)
    else
      renderFrom = Math.min(lastScreenRow, Math.max(0, firstVisibleScreenRow - @lineOverdraw))
      renderTo = Math.min(lastScreenRow, lastVisibleScreenRow + @lineOverdraw)

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

    if not @mini and @showIndentGuide
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
    else if currentLine = renderedLines.firstChild
      domPosition = 0
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

  ### Public ###

  # Retrieves the number of the row that is visible and currently at the top of the editor.
  #
  # Returns a {Number}.
  getFirstVisibleScreenRow: ->
    Math.floor(@scrollTop() / @lineHeight)

  # Retrieves the number of the row that is visible and currently at the top of the editor.
  #
  # Returns a {Number}.
  getLastVisibleScreenRow: ->
    calculatedRow = Math.ceil((@scrollTop() + @scrollView.height()) / @lineHeight) - 1
    Math.max(0, Math.min(@getScreenLineCount() - 1, calculatedRow))

  # Given a row number, identifies if it is currently visible.
  #
  # row - A row {Number} to check
  #
  # Returns a {Boolean}.
  isScreenRowVisible: (row) ->
    @getFirstVisibleScreenRow() <= row <= @getLastVisibleScreenRow()

  ### Internal ###

  handleScreenLinesChange: (change) ->
    @pendingChanges.push(change)
    @requestDisplayUpdate()

  buildLineElementForScreenRow: (screenRow) ->
    @buildLineElementsForScreenRows(screenRow, screenRow)[0]

  buildLineElementsForScreenRows: (startRow, endRow) ->
    div = document.createElement('div')
    div.innerHTML = @htmlForScreenRows(startRow, endRow)
    new Array(div.children...)

  htmlForScreenRows: (startRow, endRow) ->
    lines = @activeEditSession.linesForScreenRows(startRow, endRow)
    htmlLines = []
    screenRow = startRow
    for line in @activeEditSession.linesForScreenRows(startRow, endRow)
      htmlLines.push(@htmlForScreenLine(line, screenRow++))
    htmlLines.join('\n\n')

  htmlForScreenLine: (screenLine, screenRow) ->
    { tokens, text, lineEnding, fold, isSoftWrapped } =  screenLine
    if fold
      attributes = { class: 'fold line', 'fold-id': fold.id }
    else
      attributes = { class: 'line' }

    invisibles = @invisibles if @showInvisibles
    eolInvisibles = @getEndOfLineInvisibles(screenLine)
    htmlEolInvisibles = @buildHtmlEndOfLineInvisibles(screenLine)

    indentation = Editor.buildIndentation(screenRow, @activeEditSession)

    Editor.buildLineHtml({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, @showIndentGuide, indentation, @activeEditSession, @mini})

  @buildIndentation: (screenRow, activeEditSession) ->
    indentation = 0
    while --screenRow >= 0
      bufferRow = activeEditSession.bufferPositionForScreenPosition([screenRow]).row
      bufferLine = activeEditSession.lineForBufferRow(bufferRow)
      unless bufferLine is ''
        indentation = Math.ceil(activeEditSession.indentLevelForLine(bufferLine))
        break

    indentation

  buildHtmlEndOfLineInvisibles: (screenLine) ->
    invisibles = []
    for invisible in @getEndOfLineInvisibles(screenLine)
      invisibles.push("<span class='invisible-character'>#{invisible}</span>")
    invisibles.join('')

  getEndOfLineInvisibles: (screenLine) ->
    return [] unless @showInvisibles and @invisibles
    return [] if @mini or screenLine.isSoftWrapped()

    invisibles = []
    invisibles.push(@invisibles.cr) if @invisibles.cr and screenLine.lineEnding is '\r\n'
    invisibles.push(@invisibles.eol) if @invisibles.eol
    invisibles

  lineElementForScreenRow: (screenRow) ->
    @renderedLines.children(":eq(#{screenRow - @firstRenderedScreenRow})")

  toggleLineCommentsInSelection: ->
    @activeEditSession.toggleLineCommentsInSelection()

  ### Public ###

  # Converts a buffer position to a pixel position.
  #
  # position - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an object with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForBufferPosition: (position) ->
    @pixelPositionForScreenPosition(@screenPositionForBufferPosition(position))

  # Converts a screen position to a pixel position.
  #
  # position - An object that represents a screen position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an object with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForScreenPosition: (position) ->
    return { top: 0, left: 0 } unless @isOnDom() and @isVisible()
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
    leftPixels = range.getClientRects()[0].left - @scrollView.offset().left + @scrollLeft()
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

  # Highlights the current line the cursor is on.
  highlightCursorLine: ->
    return if @mini

    @highlightedLine?.removeClass('cursor-line')
    if @getSelection().isEmpty()
      @highlightedLine = @lineElementForScreenRow(@getCursorScreenRow())
      @highlightedLine.addClass('cursor-line')
    else
      @highlightedLine = null

  # {Delegates to: EditSession.getGrammar}
  getGrammar: ->
    @activeEditSession.getGrammar()

   # {Delegates to: EditSession.setGrammar}
  setGrammar: (grammar) ->
    throw new Error("Only mini-editors can explicity set their grammar") unless @mini
    @activeEditSession.setGrammar(grammar)

   # {Delegates to: EditSession.reloadGrammar}
  reloadGrammar: ->
    @activeEditSession.reloadGrammar()

  # Copies the current file path to the native clipboard.
  copyPathToPasteboard: ->
    path = @getPath()
    pasteboard.write(path) if path?

  ### Internal ###

  @buildLineHtml: ({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, showIndentGuide, indentation, activeEditSession, mini}) ->
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

    attributePairs = []
    attributePairs.push "#{attributeName}=\"#{value}\"" for attributeName, value of attributes
    line.push("<div #{attributePairs.join(' ')}>")

    if text == ''
      html = Editor.buildEmptyLineHtml(showIndentGuide, eolInvisibles, htmlEolInvisibles, indentation, activeEditSession, mini)
      line.push(html) if html
    else
      firstNonWhitespacePosition = text.search(/\S/)
      firstTrailingWhitespacePosition = text.search(/\s*$/)
      lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
      position = 0
      for token in tokens
        updateScopeStack(token.scopes)
        hasLeadingWhitespace =  position < firstNonWhitespacePosition
        hasTrailingWhitespace = position + token.value.length > firstTrailingWhitespacePosition
        hasIndentGuide = not mini and showIndentGuide and (hasLeadingWhitespace or lineIsWhitespaceOnly)
        line.push(token.getValueAsHtml({invisibles, hasLeadingWhitespace, hasTrailingWhitespace, hasIndentGuide}))
        position += token.value.length

    popScope() while scopeStack.length > 0
    line.push(htmlEolInvisibles) unless text == ''
    line.push("<span class='fold-marker'/>") if fold

    line.push('</div>')
    line.join('')

  @buildEmptyLineHtml: (showIndentGuide, eolInvisibles, htmlEolInvisibles, indentation, activeEditSession, mini) ->
    if not mini and showIndentGuide
      if indentation > 0
        tabLength = activeEditSession.getTabLength()
        indentGuideHtml = []
        for level in [0...indentation]
          indentLevelHtml = ["<span class='indent-guide'>"]
          for characterPosition in [0...tabLength]
            if invisible = eolInvisibles.shift()
              indentLevelHtml.push("<span class='invisible-character'>#{invisible}</span>")
            else
              indentLevelHtml.push(' ')
          indentLevelHtml.push("</span>")
          indentGuideHtml.push(indentLevelHtml.join(''))

        for invisible in eolInvisibles
          indentGuideHtml.push("<span class='invisible-character'>#{invisible}</span>")

        return indentGuideHtml.join('')

    invisibles = htmlEolInvisibles
    if invisibles.length > 0
      invisibles
    else
      '&nbsp;'

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

  consolidateSelections: (e) -> e.abortKeyBinding() unless @activeEditSession.consolidateSelections()

  logCursorScope: ->
    console.log @activeEditSession.getCursorScopes()

  transact: (fn) -> @activeEditSession.transact(fn)
  commit: -> @activeEditSession.commit()
  abort: -> @activeEditSession.abort()

  saveDebugSnapshot: ->
    atom.showSaveDialog (path) =>
      fsUtils.writeSync(path, @getDebugSnapshot()) if path

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
