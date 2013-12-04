{View, $, $$$} = require './space-pen-extensions'
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
          @input class: 'hidden-input', outlet: 'hiddenInput', 'x-bind-focus': "focused"
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
  editor: null
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
      {editor, @mini, placeholderText} = editorOrOptions ? {}

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

    @setPlaceholderText(placeholderText) if placeholderText

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
        'editor:toggle-line-numbers': =>  atom.config.toggle('editor.showLineNumbers')
        'editor:scroll-to-cursor': @scrollToCursorPosition

    documentation = {}
    for name, method of editorBindings
      do (name, method) =>
        @command name, (e) => method.call(this, e); false

  # {Delegates to: Editor.getCursor}
  getCursor: -> @editor.getCursor()

  # {Delegates to: Editor.getCursors}
  getCursors: -> @editor.getCursors()

  # {Delegates to: Editor.addCursorAtScreenPosition}
  addCursorAtScreenPosition: (screenPosition) -> @editor.addCursorAtScreenPosition(screenPosition)

  # {Delegates to: Editor.addCursorAtBufferPosition}
  addCursorAtBufferPosition: (bufferPosition) -> @editor.addCursorAtBufferPosition(bufferPosition)

  # {Delegates to: Editor.moveCursorUp}
  moveCursorUp: -> @editor.moveCursorUp()

  # {Delegates to: Editor.moveCursorDown}
  moveCursorDown: -> @editor.moveCursorDown()

  # {Delegates to: Editor.moveCursorLeft}
  moveCursorLeft: -> @editor.moveCursorLeft()

  # {Delegates to: Editor.moveCursorRight}
  moveCursorRight: -> @editor.moveCursorRight()

  # {Delegates to: Editor.moveCursorToBeginningOfWord}
  moveCursorToBeginningOfWord: -> @editor.moveCursorToBeginningOfWord()

  # {Delegates to: Editor.moveCursorToEndOfWord}
  moveCursorToEndOfWord: -> @editor.moveCursorToEndOfWord()

  # {Delegates to: Editor.moveCursorToBeginningOfNextWord}
  moveCursorToBeginningOfNextWord: -> @editor.moveCursorToBeginningOfNextWord()

  # {Delegates to: Editor.moveCursorToTop}
  moveCursorToTop: -> @editor.moveCursorToTop()

  # {Delegates to: Editor.moveCursorToBottom}
  moveCursorToBottom: -> @editor.moveCursorToBottom()

  # {Delegates to: Editor.moveCursorToBeginningOfLine}
  moveCursorToBeginningOfLine: -> @editor.moveCursorToBeginningOfLine()

  # {Delegates to: Editor.moveCursorToFirstCharacterOfLine}
  moveCursorToFirstCharacterOfLine: -> @editor.moveCursorToFirstCharacterOfLine()

  # {Delegates to: Editor.moveCursorToPreviousWordBoundary}
  moveCursorToPreviousWordBoundary: -> @editor.moveCursorToPreviousWordBoundary()

  # {Delegates to: Editor.moveCursorToNextWordBoundary}
  moveCursorToNextWordBoundary: -> @editor.moveCursorToNextWordBoundary()

  # {Delegates to: Editor.moveCursorToEndOfLine}
  moveCursorToEndOfLine: -> @editor.moveCursorToEndOfLine()

  # {Delegates to: Editor.moveLineUp}
  moveLineUp: -> @editor.moveLineUp()

  # {Delegates to: Editor.moveLineDown}
  moveLineDown: -> @editor.moveLineDown()

  # {Delegates to: Editor.setCursorScreenPosition}
  setCursorScreenPosition: (position, options) -> @editor.setCursorScreenPosition(position, options)

  # {Delegates to: Editor.duplicateLine}
  duplicateLine: -> @editor.duplicateLine()

  # {Delegates to: Editor.joinLine}
  joinLine: -> @editor.joinLine()

  # {Delegates to: Editor.getCursorScreenPosition}
  getCursorScreenPosition: -> @editor.getCursorScreenPosition()

  # {Delegates to: Editor.getCursorScreenRow}
  getCursorScreenRow: -> @editor.getCursorScreenRow()

  # {Delegates to: Editor.setCursorBufferPosition}
  setCursorBufferPosition: (position, options) -> @editor.setCursorBufferPosition(position, options)

  # {Delegates to: Editor.getCursorBufferPosition}
  getCursorBufferPosition: -> @editor.getCursorBufferPosition()

  # {Delegates to: Editor.getCurrentParagraphBufferRange}
  getCurrentParagraphBufferRange: -> @editor.getCurrentParagraphBufferRange()

  # {Delegates to: Editor.getWordUnderCursor}
  getWordUnderCursor: (options) -> @editor.getWordUnderCursor(options)

  # {Delegates to: Editor.getSelection}
  getSelection: (index) -> @editor.getSelection(index)

  # {Delegates to: Editor.getSelections}
  getSelections: -> @editor.getSelections()

  # {Delegates to: Editor.getSelectionsOrderedByBufferPosition}
  getSelectionsOrderedByBufferPosition: -> @editor.getSelectionsOrderedByBufferPosition()

  # {Delegates to: Editor.getLastSelectionInBuffer}
  getLastSelectionInBuffer: -> @editor.getLastSelectionInBuffer()

  # {Delegates to: Editor.getSelectedText}
  getSelectedText: -> @editor.getSelectedText()

  # {Delegates to: Editor.getSelectedBufferRanges}
  getSelectedBufferRanges: -> @editor.getSelectedBufferRanges()

  # {Delegates to: Editor.getSelectedBufferRange}
  getSelectedBufferRange: -> @editor.getSelectedBufferRange()

  # {Delegates to: Editor.setSelectedBufferRange}
  setSelectedBufferRange: (bufferRange, options) -> @editor.setSelectedBufferRange(bufferRange, options)

  # {Delegates to: Editor.setSelectedBufferRanges}
  setSelectedBufferRanges: (bufferRanges, options) -> @editor.setSelectedBufferRanges(bufferRanges, options)

  # {Delegates to: Editor.addSelectionForBufferRange}
  addSelectionForBufferRange: (bufferRange, options) -> @editor.addSelectionForBufferRange(bufferRange, options)

  # {Delegates to: Editor.selectRight}
  selectRight: -> @editor.selectRight()

  # {Delegates to: Editor.selectLeft}
  selectLeft: -> @editor.selectLeft()

  # {Delegates to: Editor.selectUp}
  selectUp: -> @editor.selectUp()

  # {Delegates to: Editor.selectDown}
  selectDown: -> @editor.selectDown()

  # {Delegates to: Editor.selectToTop}
  selectToTop: -> @editor.selectToTop()

  # {Delegates to: Editor.selectToBottom}
  selectToBottom: -> @editor.selectToBottom()

  # {Delegates to: Editor.selectAll}
  selectAll: -> @editor.selectAll()

  # {Delegates to: Editor.selectToBeginningOfLine}
  selectToBeginningOfLine: -> @editor.selectToBeginningOfLine()

  # {Delegates to: Editor.selectToFirstCharacterOfLine}
  selectToFirstCharacterOfLine: -> @editor.selectToFirstCharacterOfLine()

  # {Delegates to: Editor.selectToEndOfLine}
  selectToEndOfLine: -> @editor.selectToEndOfLine()

  # {Delegates to: Editor.selectToPreviousWordBoundary}
  selectToPreviousWordBoundary: -> @editor.selectToPreviousWordBoundary()

  # {Delegates to: Editor.selectToNextWordBoundary}
  selectToNextWordBoundary: -> @editor.selectToNextWordBoundary()

  # {Delegates to: Editor.addSelectionBelow}
  addSelectionBelow: -> @editor.addSelectionBelow()

  # {Delegates to: Editor.addSelectionAbove}
  addSelectionAbove: -> @editor.addSelectionAbove()

  # {Delegates to: Editor.selectToBeginningOfWord}
  selectToBeginningOfWord: -> @editor.selectToBeginningOfWord()

  # {Delegates to: Editor.selectToEndOfWord}
  selectToEndOfWord: -> @editor.selectToEndOfWord()

  # {Delegates to: Editor.selectToBeginningOfNextWord}
  selectToBeginningOfNextWord: -> @editor.selectToBeginningOfNextWord()

  # {Delegates to: Editor.selectWord}
  selectWord: -> @editor.selectWord()

  # {Delegates to: Editor.selectLine}
  selectLine: -> @editor.selectLine()

  # {Delegates to: Editor.selectToScreenPosition}
  selectToScreenPosition: (position) -> @editor.selectToScreenPosition(position)

  # {Delegates to: Editor.transpose}
  transpose: -> @editor.transpose()

  # {Delegates to: Editor.upperCase}
  upperCase: -> @editor.upperCase()

  # {Delegates to: Editor.lowerCase}
  lowerCase: -> @editor.lowerCase()

  # {Delegates to: Editor.clearSelections}
  clearSelections: -> @editor.clearSelections()

  # {Delegates to: Editor.backspace}
  backspace: -> @editor.backspace()

  # {Delegates to: Editor.backspaceToBeginningOfWord}
  backspaceToBeginningOfWord: -> @editor.backspaceToBeginningOfWord()

  # {Delegates to: Editor.backspaceToBeginningOfLine}
  backspaceToBeginningOfLine: -> @editor.backspaceToBeginningOfLine()

  # {Delegates to: Editor.delete}
  delete: -> @editor.delete()

  # {Delegates to: Editor.deleteToEndOfWord}
  deleteToEndOfWord: -> @editor.deleteToEndOfWord()

  # {Delegates to: Editor.deleteLine}
  deleteLine: -> @editor.deleteLine()

  # {Delegates to: Editor.cutToEndOfLine}
  cutToEndOfLine: -> @editor.cutToEndOfLine()

  # {Delegates to: Editor.insertText}
  insertText: (text, options) -> @editor.insertText(text, options)

  # {Delegates to: Editor.insertNewline}
  insertNewline: -> @editor.insertNewline()

  # {Delegates to: Editor.insertNewlineBelow}
  insertNewlineBelow: -> @editor.insertNewlineBelow()

  # {Delegates to: Editor.insertNewlineAbove}
  insertNewlineAbove: -> @editor.insertNewlineAbove()

  # {Delegates to: Editor.indent}
  indent: (options) -> @editor.indent(options)

  # {Delegates to: Editor.autoIndentSelectedRows}
  autoIndent: (options) -> @editor.autoIndentSelectedRows()

  # {Delegates to: Editor.indentSelectedRows}
  indentSelectedRows: -> @editor.indentSelectedRows()

  # {Delegates to: Editor.outdentSelectedRows}
  outdentSelectedRows: -> @editor.outdentSelectedRows()

  # {Delegates to: Editor.cutSelectedText}
  cutSelection: -> @editor.cutSelectedText()

  # {Delegates to: Editor.copySelectedText}
  copySelection: -> @editor.copySelectedText()

  # {Delegates to: Editor.pasteText}
  paste: (options) -> @editor.pasteText(options)

  # {Delegates to: Editor.undo}
  undo: -> @editor.undo()

  # {Delegates to: Editor.redo}
  redo: -> @editor.redo()

  # {Delegates to: Editor.createFold}
  createFold: (startRow, endRow) -> @editor.createFold(startRow, endRow)

  # {Delegates to: Editor.foldCurrentRow}
  foldCurrentRow: -> @editor.foldCurrentRow()

  # {Delegates to: Editor.unfoldCurrentRow}
  unfoldCurrentRow: -> @editor.unfoldCurrentRow()

  # {Delegates to: Editor.foldAll}
  foldAll: -> @editor.foldAll()

  # {Delegates to: Editor.unfoldAll}
  unfoldAll: -> @editor.unfoldAll()

  # {Delegates to: Editor.foldSelection}
  foldSelection: -> @editor.foldSelection()

  # {Delegates to: Editor.destroyFoldsContainingBufferRow}
  destroyFoldsContainingBufferRow: (bufferRow) -> @editor.destroyFoldsContainingBufferRow(bufferRow)

  # {Delegates to: Editor.isFoldedAtScreenRow}
  isFoldedAtScreenRow: (screenRow) -> @editor.isFoldedAtScreenRow(screenRow)

  # {Delegates to: Editor.isFoldedAtBufferRow}
  isFoldedAtBufferRow: (bufferRow) -> @editor.isFoldedAtBufferRow(bufferRow)

  # {Delegates to: Editor.isFoldedAtCursorRow}
  isFoldedAtCursorRow: -> @editor.isFoldedAtCursorRow()

  foldAllAtIndentLevel: (indentLevel) -> @editor.foldAllAtIndentLevel(indentLevel)

  # {Delegates to: Editor.lineForScreenRow}
  lineForScreenRow: (screenRow) -> @editor.lineForScreenRow(screenRow)

  # {Delegates to: Editor.linesForScreenRows}
  linesForScreenRows: (start, end) -> @editor.linesForScreenRows(start, end)

  # {Delegates to: Editor.getScreenLineCount}
  getScreenLineCount: -> @editor.getScreenLineCount()

  # Private:
  setHeightInLines: (heightInLines)->
    heightInLines ?= @calculateHeightInLines()
    @heightInLines = heightInLines if heightInLines

  # {Delegates to: Editor.setEditorWidthInChars}
  setWidthInChars: (widthInChars) ->
    widthInChars ?= @calculateWidthInChars()
    @editor.setEditorWidthInChars(widthInChars) if widthInChars

  # {Delegates to: Editor.getMaxScreenLineLength}
  getMaxScreenLineLength: -> @editor.getMaxScreenLineLength()

  # {Delegates to: Editor.getLastScreenRow}
  getLastScreenRow: -> @editor.getLastScreenRow()

  # {Delegates to: Editor.clipScreenPosition}
  clipScreenPosition: (screenPosition, options={}) -> @editor.clipScreenPosition(screenPosition, options)

  # {Delegates to: Editor.screenPositionForBufferPosition}
  screenPositionForBufferPosition: (position, options) -> @editor.screenPositionForBufferPosition(position, options)

  # {Delegates to: Editor.bufferPositionForScreenPosition}
  bufferPositionForScreenPosition: (position, options) -> @editor.bufferPositionForScreenPosition(position, options)

  # {Delegates to: Editor.screenRangeForBufferRange}
  screenRangeForBufferRange: (range) -> @editor.screenRangeForBufferRange(range)

  # {Delegates to: Editor.bufferRangeForScreenRange}
  bufferRangeForScreenRange: (range) -> @editor.bufferRangeForScreenRange(range)

  # {Delegates to: Editor.bufferRowsForScreenRows}
  bufferRowsForScreenRows: (startRow, endRow) -> @editor.bufferRowsForScreenRows(startRow, endRow)

  # Public: Emulates the "page down" key, where the last row of a buffer scrolls to become the first.
  pageDown: ->
    newScrollTop = @scrollTop() + @scrollView[0].clientHeight
    @editor.moveCursorDown(@getPageRows())
    @scrollTop(newScrollTop,  adjustVerticalScrollbar: true)

  # Public: Emulates the "page up" key, where the frst row of a buffer scrolls to become the last.
  pageUp: ->
    newScrollTop = @scrollTop() - @scrollView[0].clientHeight
    @editor.moveCursorUp(@getPageRows())
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

  setPlaceholderText: (placeholderText) ->
    return unless @mini
    @placeholderText = placeholderText
    @requestDisplayUpdate()

  getPlaceholderText: ->
    @placeholderText

  # Checkout the HEAD revision of this editor's file.
  checkoutHead: ->
    if path = @getPath()
      atom.project.getRepo()?.checkoutHead(path)

  # {Delegates to: Editor.setText}
  setText: (text) -> @editor.setText(text)

  # {Delegates to: Editor.save}
  save: -> @editor.save()

  # {Delegates to: Editor.getText}
  getText: -> @editor.getText()

  # {Delegates to: Editor.getPath}
  getPath: -> @editor?.getPath()

  # {Delegates to: Editor.transact}
  transact: (fn) -> @editor.transact(fn)

  # {Delegates to: TextBuffer.getLineCount}
  getLineCount: -> @getBuffer().getLineCount()

  # {Delegates to: TextBuffer.getLastRow}
  getLastBufferRow: -> @getBuffer().getLastRow()

  # {Delegates to: TextBuffer.getTextInRange}
  getTextInRange: (range) -> @getBuffer().getTextInRange(range)

  # {Delegates to: TextBuffer.getEofPosition}
  getEofPosition: -> @getBuffer().getEofPosition()

  # {Delegates to: TextBuffer.lineForRow}
  lineForBufferRow: (row) -> @getBuffer().lineForRow(row)

  # {Delegates to: TextBuffer.lineLengthForRow}
  lineLengthForBufferRow: (row) -> @getBuffer().lineLengthForRow(row)

  # {Delegates to: TextBuffer.rangeForRow}
  rangeForBufferRow: (row) -> @getBuffer().rangeForRow(row)

  # {Delegates to: TextBuffer.scanInRange}
  scanInBufferRange: (args...) -> @getBuffer().scanInRange(args...)

  # {Delegates to: TextBuffer.backwardsScanInRange}
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
      marker = @editor.displayBuffer.getMarker(id)
      @editor.setCursorBufferPosition(marker.getBufferRange().start)
      @editor.destroyFoldWithId(id)
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
        @editor.selectWord() unless e.shiftKey
      else if clickCount == 3
        @editor.selectLine() unless e.shiftKey

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
      @editor.mergeIntersectingSelections(isReversed: @editor.getLastSelection().isReversed())
      @editor.finalizeSelections()
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
    return if editor is @editor

    if @editor
      @saveScrollPositionForeditor()
      @editor.off(".editor")

    @editor = editor

    return unless @editor?

    @editor.setVisible(true)

    @editor.on "contents-conflicted.editor", =>
      @showBufferConflictAlert(@editor)

    @editor.on "path-changed.editor", =>
      @reloadGrammar()
      @trigger 'editor:path-changed'

    @editor.on "grammar-changed.editor", =>
      @trigger 'editor:grammar-changed'

    @editor.on 'selection-added.editor', (selection) =>
      @newCursors.push(selection.cursor)
      @newSelections.push(selection)
      @requestDisplayUpdate()

    @editor.on 'screen-lines-changed.editor', (e) =>
      @handleScreenLinesChange(e)

    @editor.on 'scroll-top-changed.editor', (scrollTop) =>
      @scrollTop(scrollTop)

    @editor.on 'scroll-left-changed.editor', (scrollLeft) =>
      @scrollLeft(scrollLeft)

    @editor.on 'soft-wrap-changed.editor', (softWrap) =>
      @setSoftWrap(softWrap)

    @trigger 'editor:path-changed'
    @resetDisplay()

    if @attached and @editor.buffer.isInConflict()
      _.defer => @showBufferConflictAlert(@editor) # Display after editor has a chance to display

  getModel: ->
    @editor

  setModel: (editor) ->
    @edit(editor)

  showBufferConflictAlert: (editor) ->
    atom.confirm
      message: editor.getPath()
      detailedMessage: "Has changed on disk. Do you want to reload it?"
      buttons:
        Reload: -> editor.getBuffer().reload()
        Cancel: null

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
    @editor.setScrollTop(@scrollTop())

  scrollBottom: (scrollBottom) ->
    if scrollBottom?
      @scrollTop(scrollBottom - @scrollView.height())
    else
      @scrollTop() + @scrollView.height()

  scrollLeft: (scrollLeft) ->
    if scrollLeft?
      @scrollView.scrollLeft(scrollLeft)
      @editor.setScrollLeft(@scrollLeft())
    else
      @scrollView.scrollLeft()

  scrollRight: (scrollRight) ->
    if scrollRight?
      @scrollView.scrollRight(scrollRight)
      @editor.setScrollLeft(@scrollLeft())
    else
      @scrollView.scrollRight()

  ### Public ###

  # Retrieves the {Editor}'s buffer.
  #
  # Returns the current {TextBuffer}.
  getBuffer: -> @editor.buffer

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

  saveScrollPositionForeditor: ->
    if @attached
      @editor.setScrollTop(@scrollTop())
      @editor.setScrollLeft(@scrollLeft())

  # Toggle soft tabs on the edit session.
  toggleSoftTabs: ->
    @editor.setSoftTabs(not @editor.getSoftTabs())

  # Toggle soft wrap on the edit session.
  toggleSoftWrap: ->
    @setWidthInChars()
    @editor.setSoftWrap(not @editor.getSoftWrap())

  # Private:
  calculateWidthInChars: ->
    Math.floor(@scrollView.width() / @charWidth)

  # Private:
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
    atom.workspaceView?.focus()

  # Private:
  beforeRemove: ->
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
    return if @editor.getSoftWrap()

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
    @saveScrollPositionForeditor()

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
    editorScrollTop = @editor.getScrollTop() ? 0
    editorScrollLeft = @editor.getScrollLeft() ? 0
    @updateLayerDimensions()
    @scrollTop(editorScrollTop)
    @scrollLeft(editorScrollLeft)
    @setSoftWrap(@editor.getSoftWrap())
    @newCursors = @editor.getAllCursors()
    @newSelections = @editor.getAllSelections()
    @updateDisplay(suppressAutoScroll: true)

  requestDisplayUpdate: ->
    return if @pendingDisplayUpdate
    return unless @isVisible()
    @pendingDisplayUpdate = true
    setImmediate =>
      @updateDisplay()
      @pendingDisplayUpdate = false

  updateDisplay: (options={}) ->
    return unless @attached and @editor
    return unless @editor.isAlive()
    unless @isOnDom() and @isVisible()
      @redrawOnReattach = true
      return

    @updateRenderedLines()
    @updatePlaceholderText()
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

  updatePlaceholderText: ->
    return unless @mini
    if (not @placeholderText) or @getText()
      @find('.placeholder-text').remove()
    else if @placeholderText and not @getText()
      element = @find('.placeholder-text')
      if element.length
        element.text(@placeholderText)
      else
        @underlayer.append($('<span/>', class: 'placeholder-text', text: @placeholderText))

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
    for line in @editor.linesForScreenRows(startRow, endRow)
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

    indentation = EditorView.buildIndentation(screenRow, @editor)

    EditorView.buildLineHtml({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, @showIndentGuide, indentation, @editor, @mini})

  @buildIndentation: (screenRow, editor) ->
    bufferRow = editor.bufferPositionForScreenPosition([screenRow]).row
    bufferLine = editor.lineForBufferRow(bufferRow)
    if bufferLine is ''
      indentation = 0
      nextRow = screenRow + 1
      while nextRow < editor.getBuffer().getLineCount()
        bufferRow = editor.bufferPositionForScreenPosition([nextRow]).row
        bufferLine = editor.lineForBufferRow(bufferRow)
        if bufferLine isnt ''
          indentation = Math.ceil(editor.indentLevelForLine(bufferLine))
          break
        nextRow++

      previousRow = screenRow - 1
      while previousRow >= 0
        bufferRow = editor.bufferPositionForScreenPosition([previousRow]).row
        bufferLine = editor.lineForBufferRow(bufferRow)
        if bufferLine isnt ''
          indentation = Math.max(indentation, Math.ceil(editor.indentLevelForLine(bufferLine)))
          break
        previousRow--

      indentation
    else
      Math.ceil(editor.indentLevelForLine(bufferLine))

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
    @editor.toggleLineCommentsInSelection()

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

  positionLeftForLineAndColumn: (lineElement, screenRow, screenColumn) ->
    return 0 if screenColumn == 0

    bufferRow = @bufferRowsForScreenRows(screenRow, screenRow)[0] ? screenRow
    bufferColumn = @bufferPositionForScreenPosition([screenRow, screenColumn]).column
    tokenizedLine = @editor.displayBuffer.tokenizedBuffer.tokenizedLines[bufferRow]

    left = 0
    index = 0
    startIndex = @bufferPositionForScreenPosition([screenRow, 0]).column
    for token in tokenizedLine.tokens
      for char in token.value
        return left if index >= bufferColumn

        if index >= startIndex
          val = @getCharacterWidthCache(token.scopes, char)
          if val?
            left += val
          else
            return @measureToColumn(lineElement, tokenizedLine, screenColumn, startIndex)

        index++
    left

  # Private:
  measureToColumn: (lineElement, tokenizedLine, screenColumn, lineStartBufferColumn) ->
    left = oldLeft = index = 0
    iterator = document.createNodeIterator(lineElement, NodeFilter.SHOW_TEXT, TextNodeFilter)

    returnLeft = null

    offsetLeft = @scrollView.offset().left
    paddingLeft = parseInt(@scrollView.css('padding-left'))

    while textNode = iterator.nextNode()
      content = textNode.textContent

      for char, i in content
        # Don't continue caching long lines :racehorse:
        break if index > LongLineLength and screenColumn < index

        # Dont return right away, finish caching the whole line
        returnLeft = left if index == screenColumn
        oldLeft = left

        scopes = tokenizedLine.tokenAtBufferColumn(lineStartBufferColumn + index)?.scopes
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
        return screenColumn * cachedCharWidth if index > LongLineLength

        index++

    returnLeft ? left

  # Private:
  getCharacterWidthCache: (scopes, char) ->
    scopes ?= NoScope
    obj = EditorView.characterWidthCache
    for scope in scopes
      obj = obj[scope]
      return null unless obj?
    obj[char]

  # Private:
  setCharacterWidthCache: (scopes, char, val) ->
    scopes ?= NoScope
    obj = EditorView.characterWidthCache
    for scope in scopes
      obj[scope] ?= {}
      obj = obj[scope]
    obj[char] = val

  # Private:
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
    @editor.getGrammar()

  # {Delegates to: Editor.setGrammar}
  setGrammar: (grammar) ->
    @editor.setGrammar(grammar)

  # {Delegates to: Editor.reloadGrammar}
  reloadGrammar: ->
    @editor.reloadGrammar()

  # {Delegates to: Editor.scopesForBufferPosition}
  scopesForBufferPosition: (bufferPosition) ->
    @editor.scopesForBufferPosition(bufferPosition)

  # Copies the current file path to the native clipboard.
  copyPathToPasteboard: ->
    path = @getPath()
    atom.pasteboard.write(path) if path?

  ### Internal ###

  @buildLineHtml: ({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, showIndentGuide, indentation, editor, mini}) ->
    scopeStack = []
    line = []

    attributePairs = ''
    attributePairs += " #{attributeName}=\"#{value}\"" for attributeName, value of attributes
    line.push("<div #{attributePairs}>")

    if text == ''
      html = EditorView.buildEmptyLineHtml(showIndentGuide, eolInvisibles, htmlEolInvisibles, indentation, editor, mini)
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

  @buildEmptyLineHtml: (showIndentGuide, eolInvisibles, htmlEolInvisibles, indentation, editor, mini) ->
    indentCharIndex = 0
    if not mini and showIndentGuide
      if indentation > 0
        tabLength = editor.getTabLength()
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

  consolidateSelections: (e) -> e.abortKeyBinding() unless @editor.consolidateSelections()

  logCursorScope: ->
    console.log @editor.getCursorScopes()

  beginTransaction: -> @editor.beginTransaction()

  commitTransaction: -> @editor.commitTransaction()

  abortTransaction: -> @editor.abortTransaction()

  logScreenLines: (start, end) ->
    @editor.logScreenLines(start, end)

  logRenderedLines: ->
    @renderedLines.find('.line').each (n) ->
      console.log n, $(this).text()
