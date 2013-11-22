{View, $, $$} = require './space-pen-extensions'
TextBuffer = require './text-buffer'
Gutter = require './gutter'
{Point, Range} = require 'telepath'
Editor = require './editor'
CursorView = require './cursor-view'
SelectionView = require './selection-view'
fs = require 'fs-plus'
_ = require 'underscore-plus'

MeasureRange = document.createRange()
TextNodeFilter = { acceptNode: -> NodeFilter.FILTER_ACCEPT }
NoScope = ['no-scope']
LongLineLength = 1000

# Public: Represents the entire visual pane in Atom.
#
# The EditorView manages the {Editor}, which manages the file buffers.
module.exports =
class EditorView extends View
  @characterWidthCache: {}
  @configDefaults:
    fontSize: 20
    showInvisibles: false
    showIndentGuide: false
    showLineNumbers: true
    autoIndent: true
    normalizeIndentOnPaste: true
    nonWordCharacters: "./\\()\"':,.;<>~!@#$%^&*|+=[]{}`~?-"
    preferredLineLength: 80
    tabLength: 2
    softWrap: false
    softTabs: true
    softWrapAtPreferredLineLength: false

  @nextEditorId: 1

  ### Internal ###

  @content: (params) ->
    attributes = { class: @classes(params), tabindex: -1 }
    _.extend(attributes, params.attributes) if params.attributes
    @div attributes, =>
      @subview 'gutter', new Gutter
      @div class: 'scroll-view', outlet: 'scrollView', =>
        @div class: 'overlayer', outlet: 'overlayer'
        @div class: 'lines', outlet: 'renderedLines'
        @div class: 'underlayer', outlet: 'underlayer', =>
          @input class: 'hidden-input', outlet: 'hiddenInput'
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

  # The constructor for setting up an `EditorView` instance.
  #
  # editorOrOptions - Either an {Editor}, or an object with one property, `mini`.
  #                        If `mini` is `true`, a "miniature" `Editor` is constructed.
  #                        Typically, this is ideal for scenarios where you need an Atom editor,
  #                        but without all the chrome, like scrollbars, gutter, _e.t.c._.
  #
  initialize: (editorOrOptions) ->
    if editorOrOptions instanceof Editor
      editor = editorOrOptions
    else
      {editor, editSession, @mini} = editorOrOptions ? {}
      editor ?= editSession # TODO: Remove this line after packages have updated their api to use Editor and EditorView

    @id = EditorView.nextEditorId++
    @lineCache = []
    @configure()
    @bindKeys()
    @handleEvents()
    @handleInputEvents()
    @cursorViews = []
    @selectionViews = []
    @pendingChanges = []
    @newCursors = []
    @newSelections = []

    if editor?
      @edit(editor)
    else if @mini
      @edit(new Editor
        buffer: TextBuffer.createAsRoot()
        softWrap: false
        tabLength: 2
        softTabs: true
      )
    else
      throw new Error("Must supply an Editor or mini: true")

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
      'editor:consolidate-selections': @consolidateSelections
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
      'editor:move-to-previous-word-boundary': @moveCursorToPreviousWordBoundary
      'editor:move-to-next-word-boundary': @moveCursorToNextWordBoundary
      'editor:select-to-end-of-line': @selectToEndOfLine
      'editor:select-to-beginning-of-line': @selectToBeginningOfLine
      'editor:select-to-end-of-word': @selectToEndOfWord
      'editor:select-to-beginning-of-word': @selectToBeginningOfWord
      'editor:select-to-beginning-of-next-word': @selectToBeginningOfNextWord
      'editor:select-to-next-word-boundary': @selectToNextWordBoundary
      'editor:select-to-previous-word-boundary': @selectToPreviousWordBoundary
      'editor:select-to-first-character-of-line': @selectToFirstCharacterOfLine
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
        'editor:indent': @indent
        'editor:auto-indent': @autoIndent
        'editor:indent-selected-rows': @indentSelectedRows
        'editor:outdent-selected-rows': @outdentSelectedRows
        'editor:newline': @insertNewline
        'editor:newline-below': @insertNewlineBelow
        'editor:newline-above': @insertNewlineAbove
        'editor:add-selection-below': @addSelectionBelow
        'editor:add-selection-above': @addSelectionAbove
        'editor:toggle-soft-tabs': @toggleSoftTabs
        'editor:toggle-soft-wrap': @toggleSoftWrap
        'editor:fold-all': @foldAll
        'editor:unfold-all': @unfoldAll
        'editor:fold-current-row': @foldCurrentRow
        'editor:unfold-current-row': @unfoldCurrentRow
        'editor:fold-selection': @foldSelection
        'editor:fold-at-indent-level-1': => @foldAllAtIndentLevel(0)
        'editor:fold-at-indent-level-2': => @foldAllAtIndentLevel(1)
        'editor:fold-at-indent-level-3': => @foldAllAtIndentLevel(2)
        'editor:fold-at-indent-level-4': => @foldAllAtIndentLevel(3)
        'editor:fold-at-indent-level-5': => @foldAllAtIndentLevel(4)
        'editor:fold-at-indent-level-6': => @foldAllAtIndentLevel(5)
        'editor:fold-at-indent-level-7': => @foldAllAtIndentLevel(6)
        'editor:fold-at-indent-level-8': => @foldAllAtIndentLevel(7)
        'editor:fold-at-indent-level-9': => @foldAllAtIndentLevel(8)
        'editor:toggle-line-comments': @toggleLineCommentsInSelection
        'editor:log-cursor-scope': @logCursorScope
        'editor:checkout-head-revision': @checkoutHead
        'editor:copy-path': @copyPathToPasteboard
        'editor:move-line-up': @moveLineUp
        'editor:move-line-down': @moveLineDown
        'editor:duplicate-line': @duplicateLine
        'editor:join-line': @joinLine
        'editor:toggle-indent-guide': => atom.config.toggle('editor.showIndentGuide')
        'editor:save-debug-snapshot': @saveDebugSnapshot
        'editor:toggle-line-numbers': =>  atom.config.toggle('editor.showLineNumbers')
        'editor:scroll-to-cursor': @scrollToCursorPosition

    documentation = {}
    for name, method of editorBindings
      do (name, method) =>
        @command name, (e) => method.call(this, e); false

  # {Delegates to: Editor.getCursor}
  getCursor: -> @activeEditSession.getCursor()

  # {Delegates to: Editor.getCursors}
  getCursors: -> @activeEditSession.getCursors()

  # {Delegates to: Editor.addCursorAtScreenPosition}
  addCursorAtScreenPosition: (screenPosition) -> @activeEditSession.addCursorAtScreenPosition(screenPosition)

  # {Delegates to: Editor.addCursorAtBufferPosition}
  addCursorAtBufferPosition: (bufferPosition) -> @activeEditSession.addCursorAtBufferPosition(bufferPosition)

  # {Delegates to: Editor.moveCursorUp}
  moveCursorUp: -> @activeEditSession.moveCursorUp()

  # {Delegates to: Editor.moveCursorDown}
  moveCursorDown: -> @activeEditSession.moveCursorDown()

  # {Delegates to: Editor.moveCursorLeft}
  moveCursorLeft: -> @activeEditSession.moveCursorLeft()

  # {Delegates to: Editor.moveCursorRight}
  moveCursorRight: -> @activeEditSession.moveCursorRight()

  # {Delegates to: Editor.moveCursorToBeginningOfWord}
  moveCursorToBeginningOfWord: -> @activeEditSession.moveCursorToBeginningOfWord()

  # {Delegates to: Editor.moveCursorToEndOfWord}
  moveCursorToEndOfWord: -> @activeEditSession.moveCursorToEndOfWord()

  # {Delegates to: Editor.moveCursorToBeginningOfNextWord}
  moveCursorToBeginningOfNextWord: -> @activeEditSession.moveCursorToBeginningOfNextWord()

  # {Delegates to: Editor.moveCursorToTop}
  moveCursorToTop: -> @activeEditSession.moveCursorToTop()

  # {Delegates to: Editor.moveCursorToBottom}
  moveCursorToBottom: -> @activeEditSession.moveCursorToBottom()

  # {Delegates to: Editor.moveCursorToBeginningOfLine}
  moveCursorToBeginningOfLine: -> @activeEditSession.moveCursorToBeginningOfLine()

  # {Delegates to: Editor.moveCursorToFirstCharacterOfLine}
  moveCursorToFirstCharacterOfLine: -> @activeEditSession.moveCursorToFirstCharacterOfLine()

  # {Delegates to: Editor.moveCursorToPreviousWordBoundary}
  moveCursorToPreviousWordBoundary: -> @activeEditSession.moveCursorToPreviousWordBoundary()

  # {Delegates to: Editor.moveCursorToNextWordBoundary}
  moveCursorToNextWordBoundary: -> @activeEditSession.moveCursorToNextWordBoundary()

  # {Delegates to: Editor.moveCursorToEndOfLine}
  moveCursorToEndOfLine: -> @activeEditSession.moveCursorToEndOfLine()

  # {Delegates to: Editor.moveLineUp}
  moveLineUp: -> @activeEditSession.moveLineUp()

  # {Delegates to: Editor.moveLineDown}
  moveLineDown: -> @activeEditSession.moveLineDown()

  # {Delegates to: Editor.setCursorScreenPosition}
  setCursorScreenPosition: (position, options) -> @activeEditSession.setCursorScreenPosition(position, options)

  # {Delegates to: Editor.duplicateLine}
  duplicateLine: -> @activeEditSession.duplicateLine()

  # {Delegates to: Editor.joinLine}
  joinLine: -> @activeEditSession.joinLine()

  # {Delegates to: Editor.getCursorScreenPosition}
  getCursorScreenPosition: -> @activeEditSession.getCursorScreenPosition()

  # {Delegates to: Editor.getCursorScreenRow}
  getCursorScreenRow: -> @activeEditSession.getCursorScreenRow()

  # {Delegates to: Editor.setCursorBufferPosition}
  setCursorBufferPosition: (position, options) -> @activeEditSession.setCursorBufferPosition(position, options)

  # {Delegates to: Editor.getCursorBufferPosition}
  getCursorBufferPosition: -> @activeEditSession.getCursorBufferPosition()

  # {Delegates to: Editor.getCurrentParagraphBufferRange}
  getCurrentParagraphBufferRange: -> @activeEditSession.getCurrentParagraphBufferRange()

  # {Delegates to: Editor.getWordUnderCursor}
  getWordUnderCursor: (options) -> @activeEditSession.getWordUnderCursor(options)

  # {Delegates to: Editor.getSelection}
  getSelection: (index) -> @activeEditSession.getSelection(index)

  # {Delegates to: Editor.getSelections}
  getSelections: -> @activeEditSession.getSelections()

  # {Delegates to: Editor.getSelectionsOrderedByBufferPosition}
  getSelectionsOrderedByBufferPosition: -> @activeEditSession.getSelectionsOrderedByBufferPosition()

  # {Delegates to: Editor.getLastSelectionInBuffer}
  getLastSelectionInBuffer: -> @activeEditSession.getLastSelectionInBuffer()

  # {Delegates to: Editor.getSelectedText}
  getSelectedText: -> @activeEditSession.getSelectedText()

  # {Delegates to: Editor.getSelectedBufferRanges}
  getSelectedBufferRanges: -> @activeEditSession.getSelectedBufferRanges()

  # {Delegates to: Editor.getSelectedBufferRange}
  getSelectedBufferRange: -> @activeEditSession.getSelectedBufferRange()

  # {Delegates to: Editor.setSelectedBufferRange}
  setSelectedBufferRange: (bufferRange, options) -> @activeEditSession.setSelectedBufferRange(bufferRange, options)

  # {Delegates to: Editor.setSelectedBufferRanges}
  setSelectedBufferRanges: (bufferRanges, options) -> @activeEditSession.setSelectedBufferRanges(bufferRanges, options)

  # {Delegates to: Editor.addSelectionForBufferRange}
  addSelectionForBufferRange: (bufferRange, options) -> @activeEditSession.addSelectionForBufferRange(bufferRange, options)

  # {Delegates to: Editor.selectRight}
  selectRight: -> @activeEditSession.selectRight()

  # {Delegates to: Editor.selectLeft}
  selectLeft: -> @activeEditSession.selectLeft()

  # {Delegates to: Editor.selectUp}
  selectUp: -> @activeEditSession.selectUp()

  # {Delegates to: Editor.selectDown}
  selectDown: -> @activeEditSession.selectDown()

  # {Delegates to: Editor.selectToTop}
  selectToTop: -> @activeEditSession.selectToTop()

  # {Delegates to: Editor.selectToBottom}
  selectToBottom: -> @activeEditSession.selectToBottom()

  # {Delegates to: Editor.selectAll}
  selectAll: -> @activeEditSession.selectAll()

  # {Delegates to: Editor.selectToBeginningOfLine}
  selectToBeginningOfLine: -> @activeEditSession.selectToBeginningOfLine()

  # {Delegates to: Editor.selectToFirstCharacterOfLine}
  selectToFirstCharacterOfLine: -> @activeEditSession.selectToFirstCharacterOfLine()

  # {Delegates to: Editor.selectToEndOfLine}
  selectToEndOfLine: -> @activeEditSession.selectToEndOfLine()

  # {Delegates to: Editor.selectToPreviousWordBoundary}
  selectToPreviousWordBoundary: -> @activeEditSession.selectToPreviousWordBoundary()

  # {Delegates to: Editor.selectToNextWordBoundary}
  selectToNextWordBoundary: -> @activeEditSession.selectToNextWordBoundary()

  # {Delegates to: Editor.addSelectionBelow}
  addSelectionBelow: -> @activeEditSession.addSelectionBelow()

  # {Delegates to: Editor.addSelectionAbove}
  addSelectionAbove: -> @activeEditSession.addSelectionAbove()

  # {Delegates to: Editor.selectToBeginningOfWord}
  selectToBeginningOfWord: -> @activeEditSession.selectToBeginningOfWord()

  # {Delegates to: Editor.selectToEndOfWord}
  selectToEndOfWord: -> @activeEditSession.selectToEndOfWord()

  # {Delegates to: Editor.selectToBeginningOfNextWord}
  selectToBeginningOfNextWord: -> @activeEditSession.selectToBeginningOfNextWord()

  # {Delegates to: Editor.selectWord}
  selectWord: -> @activeEditSession.selectWord()

  # {Delegates to: Editor.selectLine}
  selectLine: -> @activeEditSession.selectLine()

  # {Delegates to: Editor.selectToScreenPosition}
  selectToScreenPosition: (position) -> @activeEditSession.selectToScreenPosition(position)

  # {Delegates to: Editor.transpose}
  transpose: -> @activeEditSession.transpose()

  # {Delegates to: Editor.upperCase}
  upperCase: -> @activeEditSession.upperCase()

  # {Delegates to: Editor.lowerCase}
  lowerCase: -> @activeEditSession.lowerCase()

  # {Delegates to: Editor.clearSelections}
  clearSelections: -> @activeEditSession.clearSelections()

  # {Delegates to: Editor.backspace}
  backspace: -> @activeEditSession.backspace()

  # {Delegates to: Editor.backspaceToBeginningOfWord}
  backspaceToBeginningOfWord: -> @activeEditSession.backspaceToBeginningOfWord()

  # {Delegates to: Editor.backspaceToBeginningOfLine}
  backspaceToBeginningOfLine: -> @activeEditSession.backspaceToBeginningOfLine()

  # {Delegates to: Editor.delete}
  delete: -> @activeEditSession.delete()

  # {Delegates to: Editor.deleteToEndOfWord}
  deleteToEndOfWord: -> @activeEditSession.deleteToEndOfWord()

  # {Delegates to: Editor.deleteLine}
  deleteLine: -> @activeEditSession.deleteLine()

  # {Delegates to: Editor.cutToEndOfLine}
  cutToEndOfLine: -> @activeEditSession.cutToEndOfLine()

  # {Delegates to: Editor.insertText}
  insertText: (text, options) -> @activeEditSession.insertText(text, options)

  # {Delegates to: Editor.insertNewline}
  insertNewline: -> @activeEditSession.insertNewline()

  # {Delegates to: Editor.insertNewlineBelow}
  insertNewlineBelow: -> @activeEditSession.insertNewlineBelow()

  # {Delegates to: Editor.insertNewlineAbove}
  insertNewlineAbove: -> @activeEditSession.insertNewlineAbove()

  # {Delegates to: Editor.indent}
  indent: (options) -> @activeEditSession.indent(options)

  # {Delegates to: Editor.autoIndentSelectedRows}
  autoIndent: (options) -> @activeEditSession.autoIndentSelectedRows()

  # {Delegates to: Editor.indentSelectedRows}
  indentSelectedRows: -> @activeEditSession.indentSelectedRows()

  # {Delegates to: Editor.outdentSelectedRows}
  outdentSelectedRows: -> @activeEditSession.outdentSelectedRows()

  # {Delegates to: Editor.cutSelectedText}
  cutSelection: -> @activeEditSession.cutSelectedText()

  # {Delegates to: Editor.copySelectedText}
  copySelection: -> @activeEditSession.copySelectedText()

  # {Delegates to: Editor.pasteText}
  paste: (options) -> @activeEditSession.pasteText(options)

  # {Delegates to: Editor.undo}
  undo: -> @activeEditSession.undo()

  # {Delegates to: Editor.redo}
  redo: -> @activeEditSession.redo()

  # {Delegates to: Editor.createFold}
  createFold: (startRow, endRow) -> @activeEditSession.createFold(startRow, endRow)

  # {Delegates to: Editor.foldCurrentRow}
  foldCurrentRow: -> @activeEditSession.foldCurrentRow()

  # {Delegates to: Editor.unfoldCurrentRow}
  unfoldCurrentRow: -> @activeEditSession.unfoldCurrentRow()

  # {Delegates to: Editor.foldAll}
  foldAll: -> @activeEditSession.foldAll()

  # {Delegates to: Editor.unfoldAll}
  unfoldAll: -> @activeEditSession.unfoldAll()

  # {Delegates to: Editor.foldSelection}
  foldSelection: -> @activeEditSession.foldSelection()

  # {Delegates to: Editor.destroyFoldsContainingBufferRow}
  destroyFoldsContainingBufferRow: (bufferRow) -> @activeEditSession.destroyFoldsContainingBufferRow(bufferRow)

  # {Delegates to: Editor.isFoldedAtScreenRow}
  isFoldedAtScreenRow: (screenRow) -> @activeEditSession.isFoldedAtScreenRow(screenRow)

  # {Delegates to: Editor.isFoldedAtBufferRow}
  isFoldedAtBufferRow: (bufferRow) -> @activeEditSession.isFoldedAtBufferRow(bufferRow)

  # {Delegates to: Editor.isFoldedAtCursorRow}
  isFoldedAtCursorRow: -> @activeEditSession.isFoldedAtCursorRow()

  foldAllAtIndentLevel: (indentLevel) -> @activeEditSession.foldAllAtIndentLevel(indentLevel)

  # {Delegates to: Editor.lineForScreenRow}
  lineForScreenRow: (screenRow) -> @activeEditSession.lineForScreenRow(screenRow)

  # {Delegates to: Editor.linesForScreenRows}
  linesForScreenRows: (start, end) -> @activeEditSession.linesForScreenRows(start, end)

  # {Delegates to: Editor.getScreenLineCount}
  getScreenLineCount: -> @activeEditSession.getScreenLineCount()

  # Private:
  setHeightInLines: (heightInLines)->
    heightInLines ?= @calculateHeightInLines()
    @heightInLines = heightInLines if heightInLines

  # {Delegates to: Editor.setEditorWidthInChars}
  setWidthInChars: (widthInChars) ->
    widthInChars ?= @calculateWidthInChars()
    @activeEditSession.setEditorWidthInChars(widthInChars) if widthInChars

  # {Delegates to: Editor.getMaxScreenLineLength}
  getMaxScreenLineLength: -> @activeEditSession.getMaxScreenLineLength()

  # {Delegates to: Editor.getLastScreenRow}
  getLastScreenRow: -> @activeEditSession.getLastScreenRow()

  # {Delegates to: Editor.clipScreenPosition}
  clipScreenPosition: (screenPosition, options={}) -> @activeEditSession.clipScreenPosition(screenPosition, options)

  # {Delegates to: Editor.screenPositionForBufferPosition}
  screenPositionForBufferPosition: (position, options) -> @activeEditSession.screenPositionForBufferPosition(position, options)

  # {Delegates to: Editor.bufferPositionForScreenPosition}
  bufferPositionForScreenPosition: (position, options) -> @activeEditSession.bufferPositionForScreenPosition(position, options)

  # {Delegates to: Editor.screenRangeForBufferRange}
  screenRangeForBufferRange: (range) -> @activeEditSession.screenRangeForBufferRange(range)

  # {Delegates to: Editor.bufferRangeForScreenRange}
  bufferRangeForScreenRange: (range) -> @activeEditSession.bufferRangeForScreenRange(range)

  # {Delegates to: Editor.bufferRowsForScreenRows}
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

  # Checkout the HEAD revision of this editor's file.
  checkoutHead: ->
    if path = @getPath()
      atom.project.getRepo()?.checkoutHead(path)

  # {Delegates to: Editor.setText}
  setText: (text) -> @activeEditSession.setText(text)

  # {Delegates to: Editor.getText}
  getText: -> @activeEditSession.getText()

  # {Delegates to: Editor.getPath}
  getPath: -> @activeEditSession?.getPath()

  #  {Delegates to: TextBuffer.getLineCount}
  getLineCount: -> @getBuffer().getLineCount()

  #  {Delegates to: TextBuffer.getLastRow}
  getLastBufferRow: -> @getBuffer().getLastRow()

  #  {Delegates to: TextBuffer.getTextInRange}
  getTextInRange: (range) -> @getBuffer().getTextInRange(range)

  #  {Delegates to: TextBuffer.getEofPosition}
  getEofPosition: -> @getBuffer().getEofPosition()

  #  {Delegates to: TextBuffer.lineForRow}
  lineForBufferRow: (row) -> @getBuffer().lineForRow(row)

  #  {Delegates to: TextBuffer.lineLengthForRow}
  lineLengthForBufferRow: (row) -> @getBuffer().lineLengthForRow(row)

  #  {Delegates to: TextBuffer.rangeForRow}
  rangeForBufferRow: (row) -> @getBuffer().rangeForRow(row)

  #  {Delegates to: TextBuffer.scanInRange}
  scanInBufferRange: (args...) -> @getBuffer().scanInRange(args...)

  #  {Delegates to: TextBuffer.backwardsScanInRange}
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
      @bringHiddenInputIntoView()
      @isFocused = true
      @addClass 'is-focused'

    @hiddenInput.on 'focusout', =>
      @bringHiddenInputIntoView()
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
      id = $(e.currentTarget).attr('fold-id')
      marker = @activeEditSession.displayBuffer.getMarker(id)
      @activeEditSession.setCursorBufferPosition(marker.getBufferRange().start)
      @activeEditSession.destroyFoldWithId(id)
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

    unless @mini
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

    # Listen for overflow events to detect when the editor's width changes
    # to update the soft wrap column.
    updateWidthInChars = _.debounce((=> @setWidthInChars()), 100)
    @scrollView.on 'overflowchanged', =>
      updateWidthInChars() if @[0].classList.contains('soft-wrap')

  handleInputEvents: ->
    @on 'cursor:moved', =>
      return unless @isFocused
      cursorView = @getCursorView()

      if cursorView.isVisible()
        # This is an order of magnitude faster than checking .offset().
        style = cursorView[0].style
        @hiddenInput[0].style.top = style.top
        @hiddenInput[0].style.left = style.left

    selectedText = null
    @hiddenInput.on 'compositionstart', =>
      selectedText = @getSelectedText()
      @hiddenInput.css('width', '100%')
    @hiddenInput.on 'compositionupdate', (e) =>
      @insertText(e.originalEvent.data, {select: true, undo: 'skip'})
    @hiddenInput.on 'compositionend', =>
      @insertText(selectedText, {select: true, undo: 'skip'})
      @hiddenInput.css('width', '1px')

    lastInput = ''
    @on "textInput", (e) =>
      # Work around of the accented character suggestion feature in OS X.
      selectedLength = @hiddenInput[0].selectionEnd - @hiddenInput[0].selectionStart
      if selectedLength is 1 and lastInput is @hiddenInput.val()
        @selectLeft()

      lastInput = e.originalEvent.data
      @insertText(lastInput)
      @hiddenInput.val(lastInput)
      false

  bringHiddenInputIntoView: ->
    @hiddenInput.css(top: @scrollTop(), left: @scrollLeft())

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
      @activeEditSession.mergeIntersectingSelections(isReversed: @activeEditSession.getLastSelection().isReversed())
      @activeEditSession.finalizeSelections()
      @syncCursorAnimations()

  afterAttach: (onDom) ->
    return unless onDom
    @redraw() if @redrawOnReattach
    return if @attached
    @attached = true
    @calculateDimensions()
    @setWidthInChars()
    @subscribe $(window), "resize.editor-#{@id}", =>
      @setHeightInLines()
      @setWidthInChars()
      @updateLayerDimensions()
      @requestDisplayUpdate()
    @focus() if @isFocused

    if pane = @getPane()
      @active = @is(pane.activeView)
      @subscribe pane, 'pane:active-item-changed', (event, item) =>
        wasActive = @active
        @active = @is(pane.activeView)
        @redraw() if @active and not wasActive

    @resetDisplay()

    @trigger 'editor:attached', [this]

  edit: (editor) ->
    return if editor is @activeEditSession

    if @activeEditSession
      @saveScrollPositionForActiveEditSession()
      @activeEditSession.off(".editor")

    @activeEditSession = editor

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

    @activeEditSession.on 'scroll-top-changed.editor', (scrollTop) =>
      @scrollTop(scrollTop)

    @activeEditSession.on 'scroll-left-changed.editor', (scrollLeft) =>
      @scrollLeft(scrollLeft)

    @activeEditSession.on 'soft-wrap-changed.editor', (softWrap) =>
      @setSoftWrap(softWrap)

    @trigger 'editor:path-changed'
    @resetDisplay()

    if @attached and @activeEditSession.buffer.isInConflict()
      _.defer => @showBufferConflictAlert(@activeEditSession) # Display after editor has a chance to display

  getModel: ->
    @activeEditSession

  setModel: (editor) ->
    @edit(editor)

  showBufferConflictAlert: (editor) ->
    atom.confirm(
      editor.getPath(),
      "Has changed on disk. Do you want to reload it?",
      "Reload", (=> editor.buffer.reload()),
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

  # Retrieves the {Editor}'s buffer.
  #
  # Returns the current {TextBuffer}.
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

  # Highlight all the folds within the given buffer range.
  #
  # "Highlighting" essentially just adds the `fold-selected` class to the line's
  # DOM element.
  #
  # bufferRange - The {Range} to check.
  highlightFoldsContainingBufferRange: (bufferRange) ->
    screenLines = @linesForScreenRows(@firstRenderedScreenRow, @lastRenderedScreenRow)
    for screenLine, i in screenLines
      if fold = screenLine.fold
        screenRow = @firstRenderedScreenRow + i
        element = @lineElementForScreenRow(screenRow)

        if bufferRange.intersectsWith(fold.getBufferRange())
          element.addClass('fold-selected')
        else
          element.removeClass('fold-selected')

  saveScrollPositionForActiveEditSession: ->
    if @attached
      @activeEditSession.setScrollTop(@scrollTop())
      @activeEditSession.setScrollLeft(@scrollLeft())

  # Toggle soft tabs on the edit session.
  toggleSoftTabs: ->
    @activeEditSession.setSoftTabs(not @activeEditSession.getSoftTabs())

  # Toggle soft wrap on the edit session.
  toggleSoftWrap: ->
    @setWidthInChars()
    @activeEditSession.setSoftWrap(not @activeEditSession.getSoftWrap())

  calculateWidthInChars: ->
    Math.floor(@scrollView.width() / @charWidth)

  calculateHeightInLines: ->
    Math.ceil($(window).height() / @lineHeight)

  # Enables/disables soft wrap on the editor.
  #
  # softWrap - A {Boolean} which, if `true`, enables soft wrap
  setSoftWrap: (softWrap) ->
    if softWrap
      @addClass 'soft-wrap'
      @scrollLeft(0)
    else
      @removeClass 'soft-wrap'

  # Sets the font size for the editor.
  #
  # fontSize - A {Number} indicating the font size in pixels.
  setFontSize: (fontSize) ->
    @css('font-size', "#{fontSize}px}")

    @clearCharacterWidthCache()

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
  setFontFamily: (fontFamily='') ->
    @css('font-family', fontFamily)

    @clearCharacterWidthCache()

    @redraw()

  # Gets the font family for the editor.
  #
  # Returns a {String} identifying the CSS `font-family`,
  getFontFamily: -> @css("font-family")

  # Redraw the editor
  redraw: ->
    return unless @hasParent()
    return unless @attached
    @redrawOnReattach = false
    @calculateDimensions()
    @updatePaddingOfRenderedLines()
    @updateLayerDimensions()
    @requestDisplayUpdate()

  splitLeft: ->
    pane = @getPane()
    pane?.splitLeft(pane?.copyActiveItem()).activeView

  splitRight: ->
    pane = @getPane()
    pane?.splitRight(pane?.copyActiveItem()).activeView

  splitUp: ->
    pane = @getPane()
    pane?.splitUp(pane?.copyActiveItem()).activeView

  splitDown: ->
    pane = @getPane()
    pane?.splitDown(pane?.copyActiveItem()).activeView

  # Retrieve's the `EditorView`'s pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parent('.item-views').parent('.pane').view()

  remove: (selector, keepData) ->
    return super if keepData or @removed
    super
    atom.rootView?.focus()

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
    selectionView = new SelectionView({editorView: this, selection})
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
    @setHeightInLines()

  updateLayerDimensions: ->
    height = @lineHeight * @getScreenLineCount()
    unless @layerHeight == height
      @layerHeight = height
      @underlayer.height(@layerHeight)
      @renderedLines.height(@layerHeight)
      @overlayer.height(@layerHeight)
      @verticalScrollbarContent.height(@layerHeight)
      @scrollBottom(height) if @scrollBottom() > height

    minWidth = Math.max(@charWidth * @getMaxScreenLineLength() + 20, @scrollView.width())
    unless @layerMinWidth == minWidth
      @renderedLines.css('min-width', minWidth)
      @underlayer.css('min-width', minWidth)
      @overlayer.css('min-width', minWidth)
      @layerMinWidth = minWidth
      @trigger 'editor:min-width-changed'

  # Override for speed. The base function checks computedStyle, unnecessary here.
  isHidden: ->
    style = this[0].style
    if style.display == 'none' or not @isOnDom()
      true
    else
      false

  clearRenderedLines: ->
    @renderedLines.empty()
    @firstRenderedScreenRow = null
    @lastRenderedScreenRow = null

  resetDisplay: ->
    return unless @attached

    @clearRenderedLines()
    @removeAllCursorAndSelectionViews()
    editorScrollTop = @activeEditSession.getScrollTop() ? 0
    editorScrollLeft = @activeEditSession.getScrollLeft() ? 0
    @updateLayerDimensions()
    @scrollTop(editorScrollTop)
    @scrollLeft(editorScrollLeft)
    @setSoftWrap(@activeEditSession.getSoftWrap())
    @newCursors = @activeEditSession.getAllCursors()
    @newSelections = @activeEditSession.getAllSelections()
    @updateDisplay(suppressAutoScroll: true)

  requestDisplayUpdate: ->
    return if @pendingDisplayUpdate
    return unless @isVisible()
    @pendingDisplayUpdate = true
    setImmediate =>
      @updateDisplay()
      @pendingDisplayUpdate = false

  updateDisplay: (options={}) ->
    return unless @attached and @activeEditSession
    return if @activeEditSession.destroyed
    unless @isOnDom() and @isVisible()
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
      else if @shouldUpdateCursor(cursorView)
        cursorView.updateDisplay()

  shouldUpdateCursor: (cursorView) ->
    return false unless cursorView.needsUpdate

    pos = cursorView.getScreenPosition()
    pos.row >= @firstRenderedScreenRow and pos.row <= @lastRenderedScreenRow

  updateSelectionViews: ->
    if @newSelections.length > 0
      @addSelectionView(selection) for selection in @newSelections when not selection.destroyed
      @newSelections = []

    for selectionView in @getSelectionViews()
      if selectionView.needsRemoval
        selectionView.remove()
      else if @shouldUpdateSelection(selectionView)
        selectionView.updateDisplay()

  shouldUpdateSelection: (selectionView) ->
    screenRange = selectionView.getScreenRange()
    startRow = screenRange.start.row
    endRow = screenRange.end.row
    (startRow >= @firstRenderedScreenRow and startRow <= @lastRenderedScreenRow) or # startRow in range
      (endRow >= @firstRenderedScreenRow and endRow <= @lastRenderedScreenRow) or # endRow in range
      (startRow <= @firstRenderedScreenRow and endRow >= @lastRenderedScreenRow) # selection surrounds the rendered items

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
    lastScreenRowToRender = firstVisibleScreenRow + @heightInLines - 1
    lastScreenRow = @getLastScreenRow()

    if @firstRenderedScreenRow? and firstVisibleScreenRow >= @firstRenderedScreenRow and lastScreenRowToRender <= @lastRenderedScreenRow
      renderFrom = Math.min(lastScreenRow, @firstRenderedScreenRow)
      renderTo = Math.min(lastScreenRow, @lastRenderedScreenRow)
    else
      renderFrom = Math.min(lastScreenRow, Math.max(0, firstVisibleScreenRow - @lineOverdraw))
      renderTo = Math.min(lastScreenRow, lastScreenRowToRender + @lineOverdraw)

    if @pendingChanges.length == 0 and @firstRenderedScreenRow and @firstRenderedScreenRow <= renderFrom and renderTo <= @lastRenderedScreenRow
      return

    changes = @pendingChanges
    intactRanges = @computeIntactRanges(renderFrom, renderTo)

    @gutter.updateLineNumbers(changes, renderFrom, renderTo)

    @clearDirtyRanges(intactRanges)
    @fillDirtyRanges(intactRanges, renderFrom, renderTo)
    @firstRenderedScreenRow = renderFrom
    @lastRenderedScreenRow = renderTo
    @updateLayerDimensions()
    @updatePaddingOfRenderedLines()

  computeSurroundingEmptyLineChanges: (change) ->
    emptyLineChanges = []

    if change.bufferDelta?
      afterStart = change.end + change.bufferDelta + 1
      if @lineForBufferRow(afterStart) is ''
        afterEnd = afterStart
        afterEnd++ while @lineForBufferRow(afterEnd + 1) is ''
        emptyLineChanges.push({start: afterStart, end: afterEnd, screenDelta: 0})

      beforeEnd = change.start - 1
      if @lineForBufferRow(beforeEnd) is ''
        beforeStart = beforeEnd
        beforeStart-- while @lineForBufferRow(beforeStart - 1) is ''
        emptyLineChanges.push({start: beforeStart, end: beforeEnd, screenDelta: 0})

    emptyLineChanges

  computeIntactRanges: (renderFrom, renderTo) ->
    return [] if !@firstRenderedScreenRow? and !@lastRenderedScreenRow?

    intactRanges = [{start: @firstRenderedScreenRow, end: @lastRenderedScreenRow, domStart: 0}]

    if not @mini and @showIndentGuide
      emptyLineChanges = []
      for change in @pendingChanges
        emptyLineChanges.push(@computeSurroundingEmptyLineChanges(change)...)
      @pendingChanges.push(emptyLineChanges...)

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

    @truncateIntactRanges(intactRanges, renderFrom, renderTo)

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
    if intactRanges.length == 0
      @renderedLines[0].innerHTML = ''
    else if currentLine = @renderedLines[0].firstChild
      domPosition = 0
      for intactRange in intactRanges
        while intactRange.domStart > domPosition
          currentLine = @clearLine(currentLine)
          domPosition++
        for i in [intactRange.start..intactRange.end]
          currentLine = currentLine.nextSibling
          domPosition++
      while currentLine
        currentLine = @clearLine(currentLine)

  clearLine: (lineElement) ->
    next = lineElement.nextSibling
    @renderedLines[0].removeChild(lineElement)
    next

  fillDirtyRanges: (intactRanges, renderFrom, renderTo) ->
    i = 0
    nextIntact = intactRanges[i]
    currentLine = @renderedLines[0].firstChild

    row = renderFrom
    while row <= renderTo
      if row == nextIntact?.end + 1
        nextIntact = intactRanges[++i]

      if !nextIntact or row < nextIntact.start
        if nextIntact
          dirtyRangeEnd = nextIntact.start - 1
        else
          dirtyRangeEnd = renderTo

        for lineElement in @buildLineElementsForScreenRows(row, dirtyRangeEnd)
          @renderedLines[0].insertBefore(lineElement, currentLine)
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
    screenRow = Math.floor(@scrollTop() / @lineHeight)
    screenRow = 0 if isNaN(screenRow)
    screenRow

  # Retrieves the number of the row that is visible and currently at the bottom of the editor.
  #
  # Returns a {Number}.
  getLastVisibleScreenRow: ->
    calculatedRow = Math.ceil((@scrollTop() + @scrollView.height()) / @lineHeight) - 1
    screenRow = Math.max(0, Math.min(@getScreenLineCount() - 1, calculatedRow))
    screenRow = 0 if isNaN(screenRow)
    screenRow

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
    htmlLines = ''
    screenRow = startRow
    for line in @activeEditSession.linesForScreenRows(startRow, endRow)
      htmlLines += @htmlForScreenLine(line, screenRow++)
    htmlLines

  htmlForScreenLine: (screenLine, screenRow) ->
    { tokens, text, lineEnding, fold, isSoftWrapped } =  screenLine
    if fold
      attributes = { class: 'fold line', 'fold-id': fold.id }
    else
      attributes = { class: 'line' }

    invisibles = @invisibles if @showInvisibles
    eolInvisibles = @getEndOfLineInvisibles(screenLine)
    htmlEolInvisibles = @buildHtmlEndOfLineInvisibles(screenLine)

    indentation = EditorView.buildIndentation(screenRow, @activeEditSession)

    EditorView.buildLineHtml({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, @showIndentGuide, indentation, @activeEditSession, @mini})

  @buildIndentation: (screenRow, activeEditSession) ->
    bufferRow = activeEditSession.bufferPositionForScreenPosition([screenRow]).row
    bufferLine = activeEditSession.lineForBufferRow(bufferRow)
    if bufferLine is ''
      indentation = 0
      nextRow = screenRow + 1
      while nextRow < activeEditSession.getBuffer().getLineCount()
        bufferRow = activeEditSession.bufferPositionForScreenPosition([nextRow]).row
        bufferLine = activeEditSession.lineForBufferRow(bufferRow)
        if bufferLine isnt ''
          indentation = Math.ceil(activeEditSession.indentLevelForLine(bufferLine))
          break
        nextRow++

      previousRow = screenRow - 1
      while previousRow >= 0
        bufferRow = activeEditSession.bufferPositionForScreenPosition([previousRow]).row
        bufferLine = activeEditSession.lineForBufferRow(bufferRow)
        if bufferLine isnt ''
          indentation = Math.max(indentation, Math.ceil(activeEditSession.indentLevelForLine(bufferLine)))
          break
        previousRow--

      indentation
    else
      Math.ceil(activeEditSession.indentLevelForLine(bufferLine))

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
    left = @positionLeftForLineAndColumn(lineElement, actualRow, column)
    unless existingLineElement
      @renderedLines[0].removeChild(lineElement)
    { top: row * @lineHeight, left }

  positionLeftForLineAndColumn: (lineElement, screenRow, column) ->
    return 0 if column == 0

    bufferRow = @bufferRowsForScreenRows(screenRow, screenRow)[0] ? screenRow
    tokenizedLine = @activeEditSession.displayBuffer.tokenizedBuffer.tokenizedLines[bufferRow]

    left = 0
    index = 0
    for token in tokenizedLine.tokens
      for char in token.value
        return left if index >= column

        val = @getCharacterWidthCache(token.scopes, char)
        if val?
          left += val
        else
          return @measureToColumn(lineElement, tokenizedLine, column)

        index++
    left

  scopesForColumn: (tokenizedLine, column) ->
    index = 0
    for token in tokenizedLine.tokens
      for char in token.value
        return token.scopes if index == column
        index++
    null

  measureToColumn: (lineElement, tokenizedLine, column) ->
    left = oldLeft = index = 0
    iterator = document.createNodeIterator(lineElement, NodeFilter.SHOW_TEXT, TextNodeFilter)

    returnLeft = null

    offsetLeft = @scrollView.offset().left
    paddingLeft = parseInt(@scrollView.css('padding-left'))

    while textNode = iterator.nextNode()
      content = textNode.textContent

      for char, i in content
        # Don't continue caching long lines :racehorse:
        break if index > LongLineLength and column < index

        # Dont return right away, finish caching the whole line
        returnLeft = left if index == column
        oldLeft = left

        scopes = @scopesForColumn(tokenizedLine, index)
        cachedCharWidth = @getCharacterWidthCache(scopes, char)

        if cachedCharWidth?
          left = oldLeft + cachedCharWidth
        else
          # i + 1 to measure to the end of the current character
          MeasureRange.setEnd(textNode, i + 1)
          MeasureRange.collapse()
          rects = MeasureRange.getClientRects()
          return 0 if rects.length == 0
          left = rects[0].left - Math.floor(offsetLeft) + Math.floor(@scrollLeft()) - paddingLeft

          if scopes?
            cachedCharWidth = left - oldLeft
            @setCharacterWidthCache(scopes, char, cachedCharWidth)

        # Assume all the characters are the same width when dealing with long
        # lines :racehorse:
        return column * cachedCharWidth if index > LongLineLength

        index++

    returnLeft ? left

  getCharacterWidthCache: (scopes, char) ->
    scopes ?= NoScope
    obj = EditorView.characterWidthCache
    for scope in scopes
      obj = obj[scope]
      return null unless obj?
    obj[char]

  setCharacterWidthCache: (scopes, char, val) ->
    scopes ?= NoScope
    obj = EditorView.characterWidthCache
    for scope in scopes
      obj[scope] ?= {}
      obj = obj[scope]
    obj[char] = val

  clearCharacterWidthCache: ->
    EditorView.characterWidthCache = {}

  pixelOffsetForScreenPosition: (position) ->
    {top, left} = @pixelPositionForScreenPosition(position)
    offset = @renderedLines.offset()
    {top: top + offset.top, left: left + offset.left}

  screenPositionFromMouseEvent: (e) ->
    { pageX, pageY } = e
    offset = @scrollView.offset()

    editorRelativeTop = pageY - offset.top + @scrollTop()
    row = Math.floor(editorRelativeTop / @lineHeight)
    column = 0

    if pageX > offset.left and lineElement = @lineElementForScreenRow(row)[0]
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

  # {Delegates to: Editor.getGrammar}
  getGrammar: ->
    @activeEditSession.getGrammar()

  # {Delegates to: Editor.setGrammar}
  setGrammar: (grammar) ->
    throw new Error("Only mini-editors can explicity set their grammar") unless @mini
    @activeEditSession.setGrammar(grammar)

  # {Delegates to: Editor.reloadGrammar}
  reloadGrammar: ->
    @activeEditSession.reloadGrammar()

  # {Delegates to: Editor.scopesForBufferPosition}
  scopesForBufferPosition: (bufferPosition) ->
    @activeEditSession.scopesForBufferPosition(bufferPosition)

  # Copies the current file path to the native clipboard.
  copyPathToPasteboard: ->
    path = @getPath()
    atom.pasteboard.write(path) if path?

  ### Internal ###

  @buildLineHtml: ({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, showIndentGuide, indentation, activeEditSession, mini}) ->
    scopeStack = []
    line = []

    attributePairs = ''
    attributePairs += " #{attributeName}=\"#{value}\"" for attributeName, value of attributes
    line.push("<div #{attributePairs}>")

    if text == ''
      html = EditorView.buildEmptyLineHtml(showIndentGuide, eolInvisibles, htmlEolInvisibles, indentation, activeEditSession, mini)
      line.push(html) if html
    else
      firstNonWhitespacePosition = text.search(/\S/)
      firstTrailingWhitespacePosition = text.search(/\s*$/)
      lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
      position = 0
      for token in tokens
        @updateScopeStack(line, scopeStack, token.scopes)
        hasLeadingWhitespace =  position < firstNonWhitespacePosition
        hasTrailingWhitespace = position + token.value.length > firstTrailingWhitespacePosition
        hasIndentGuide = not mini and showIndentGuide and (hasLeadingWhitespace or lineIsWhitespaceOnly)
        line.push(token.getValueAsHtml({invisibles, hasLeadingWhitespace, hasTrailingWhitespace, hasIndentGuide}))
        position += token.value.length

    @popScope(line, scopeStack) while scopeStack.length > 0
    line.push(htmlEolInvisibles) unless text == ''
    line.push("<span class='fold-marker'/>") if fold

    line.push('</div>')
    line.join('')

  @updateScopeStack: (line, scopeStack, desiredScopes) ->
    excessScopes = scopeStack.length - desiredScopes.length
    if excessScopes > 0
      @popScope(line, scopeStack) while excessScopes--

    # pop until common prefix
    for i in [scopeStack.length..0]
      break if _.isEqual(scopeStack[0...i], desiredScopes[0...i])
      @popScope(line, scopeStack)

    # push on top of common prefix until scopeStack == desiredScopes
    for j in [i...desiredScopes.length]
      @pushScope(line, scopeStack, desiredScopes[j])

    null

  @pushScope: (line, scopeStack, scope) ->
    scopeStack.push(scope)
    line.push("<span class=\"#{scope.replace(/\./g, ' ')}\">")

  @popScope: (line, scopeStack) ->
    scopeStack.pop()
    line.push("</span>")

  @buildEmptyLineHtml: (showIndentGuide, eolInvisibles, htmlEolInvisibles, indentation, activeEditSession, mini) ->
    indentCharIndex = 0
    if not mini and showIndentGuide
      if indentation > 0
        tabLength = activeEditSession.getTabLength()
        indentGuideHtml = ''
        for level in [0...indentation]
          indentLevelHtml = "<span class='indent-guide'>"
          for characterPosition in [0...tabLength]
            if invisible = eolInvisibles[indentCharIndex++]
              indentLevelHtml += "<span class='invisible-character'>#{invisible}</span>"
            else
              indentLevelHtml += ' '
          indentLevelHtml += "</span>"
          indentGuideHtml += indentLevelHtml

        while indentCharIndex < eolInvisibles.length
          indentGuideHtml += "<span class='invisible-character'>#{eolInvisibles[indentCharIndex++]}</span>"

        return indentGuideHtml

    if htmlEolInvisibles.length > 0
      htmlEolInvisibles
    else
      '&nbsp;'

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
  beginTransaction: -> @activeEditSession.beginTransaction()
  commitTransaction: -> @activeEditSession.commitTransaction()
  abortTransaction: -> @activeEditSession.abortTransaction()

  saveDebugSnapshot: ->
    atom.showSaveDialog (path) =>
      fs.writeFileSync(path, @getDebugSnapshot()) if path

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
