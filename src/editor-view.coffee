{View, $, $$$} = require './space-pen-extensions'
GutterView = require './gutter-view'
{Point, Range} = require 'text-buffer'
Editor = require './editor'
CursorView = require './cursor-view'
SelectionView = require './selection-view'
fs = require 'fs-plus'
_ = require 'underscore-plus'
TextBuffer = require 'text-buffer'

MeasureRange = document.createRange()
TextNodeFilter = { acceptNode: -> NodeFilter.FILTER_ACCEPT }
NoScope = ['no-scope']
LongLineLength = 1000

# Public: Represents the entire visual pane in Atom.
#
# The EditorView manages the {Editor}, which manages the file buffers.
#
# ## Requiring in packages
#
# ```coffee
# {EditorView} = require 'atom'
#
# miniEditorView = new EditorView(mini: true)
# ```
#
# ## Iterating over the open editor views
#
# ```coffee
# for editorView in atom.workspaceView.getEditorViews()
#   console.log(editorView.getEditor().getPath())
# ```
#
# ## Subscribing to every current and future editor
#
# ```coffee
# atom.workspace.eachEditorView (editorView) ->
#   console.log(editorView.getEditor().getPath())
# ```
module.exports =
class EditorView extends View
  @characterWidthCache: {}
  @configDefaults:
    fontFamily: ''
    fontSize: 16
    lineHeight: 1.3
    showInvisibles: false
    showIndentGuide: false
    showLineNumbers: true
    autoIndent: true
    normalizeIndentOnPaste: true
    nonWordCharacters: "/\\()\"':,.;<>~!@#$%^&*|+=[]{}`?-"
    preferredLineLength: 80
    tabLength: 2
    softWrap: false
    softTabs: true
    softWrapAtPreferredLineLength: false
    scrollSensitivity: 40
    useHardwareAcceleration: true
    confirmCheckoutHeadRevision: true
    invisibles:
      eol: '\u00ac'
      space: '\u00b7'
      tab: '\u00bb'
      cr: '\u00a4'

  @nextEditorId: 1

  @content: (params) ->
    attributes = { class: @classes(params), tabindex: -1 }
    _.extend(attributes, params.attributes) if params.attributes
    @div attributes, =>
      @subview 'gutter', new GutterView
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
  editor: null
  attached: false
  lineOverdraw: 10
  pendingChanges: null
  newCursors: null
  newSelections: null
  redrawOnReattach: false
  bottomPaddingInLines: 10

  # The constructor for setting up an `EditorView` instance.
  #
  # editorOrOptions - Either an {Editor}, or an object with one property, `mini`.
  #                   If `mini` is `true`, a "miniature" `Editor` is constructed.
  #                   Typically, this is ideal for scenarios where you need an Atom editor,
  #                   but without all the chrome, like scrollbars, gutter, _e.t.c._.
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
        buffer: new TextBuffer
        softWrap: false
        tabLength: 2
        softTabs: true
      )
    else
      throw new Error("Must supply an Editor or mini: true")

  # Sets up the core Atom commands.
  #
  # Some commands are excluded from mini-editors.
  bindKeys: ->
    editorBindings =
      'core:move-left': => @editor.moveCursorLeft()
      'core:move-right': => @editor.moveCursorRight()
      'core:select-left': => @editor.selectLeft()
      'core:select-right': => @editor.selectRight()
      'core:select-all': => @editor.selectAll()
      'core:backspace': => @editor.backspace()
      'core:delete': => @editor.delete()
      'core:undo': => @editor.undo()
      'core:redo': => @editor.redo()
      'core:cut': => @editor.cutSelectedText()
      'core:copy': => @editor.copySelectedText()
      'core:paste': => @editor.pasteText()
      'editor:move-to-previous-word': => @editor.moveCursorToPreviousWord()
      'editor:select-word': => @editor.selectWord()
      'editor:consolidate-selections': (event) => @consolidateSelections(event)
      'editor:delete-to-beginning-of-word': => @editor.deleteToBeginningOfWord()
      'editor:delete-to-beginning-of-line': => @editor.deleteToBeginningOfLine()
      'editor:delete-to-end-of-line': => @editor.deleteToEndOfLine()
      'editor:delete-to-end-of-word': => @editor.deleteToEndOfWord()
      'editor:delete-line': => @editor.deleteLine()
      'editor:cut-to-end-of-line': => @editor.cutToEndOfLine()
      'editor:move-to-beginning-of-next-paragraph': => @editor.moveCursorToBeginningOfNextParagraph()
      'editor:move-to-beginning-of-previous-paragraph': => @editor.moveCursorToBeginningOfPreviousParagraph()
      'editor:move-to-beginning-of-screen-line': => @editor.moveCursorToBeginningOfScreenLine()
      'editor:move-to-beginning-of-line': => @editor.moveCursorToBeginningOfLine()
      'editor:move-to-end-of-screen-line': => @editor.moveCursorToEndOfScreenLine()
      'editor:move-to-end-of-line': => @editor.moveCursorToEndOfLine()
      'editor:move-to-first-character-of-line': => @editor.moveCursorToFirstCharacterOfLine()
      'editor:move-to-beginning-of-word': => @editor.moveCursorToBeginningOfWord()
      'editor:move-to-end-of-word': => @editor.moveCursorToEndOfWord()
      'editor:move-to-beginning-of-next-word': => @editor.moveCursorToBeginningOfNextWord()
      'editor:move-to-previous-word-boundary': => @editor.moveCursorToPreviousWordBoundary()
      'editor:move-to-next-word-boundary': => @editor.moveCursorToNextWordBoundary()
      'editor:select-to-beginning-of-next-paragraph': => @editor.selectToBeginningOfNextParagraph()
      'editor:select-to-beginning-of-previous-paragraph': => @editor.selectToBeginningOfPreviousParagraph()
      'editor:select-to-end-of-line': => @editor.selectToEndOfLine()
      'editor:select-to-beginning-of-line': => @editor.selectToBeginningOfLine()
      'editor:select-to-end-of-word': => @editor.selectToEndOfWord()
      'editor:select-to-beginning-of-word': => @editor.selectToBeginningOfWord()
      'editor:select-to-beginning-of-next-word': => @editor.selectToBeginningOfNextWord()
      'editor:select-to-next-word-boundary': => @editor.selectToNextWordBoundary()
      'editor:select-to-previous-word-boundary': => @editor.selectToPreviousWordBoundary()
      'editor:select-to-first-character-of-line': => @editor.selectToFirstCharacterOfLine()
      'editor:select-line': => @editor.selectLine()
      'editor:transpose': => @editor.transpose()
      'editor:upper-case': => @editor.upperCase()
      'editor:lower-case': => @editor.lowerCase()

    unless @mini
      _.extend editorBindings,
        'core:move-up': => @editor.moveCursorUp()
        'core:move-down': => @editor.moveCursorDown()
        'core:move-to-top': => @editor.moveCursorToTop()
        'core:move-to-bottom': => @editor.moveCursorToBottom()
        'core:page-up': => @pageUp()
        'core:page-down': => @pageDown()
        'core:select-up': => @editor.selectUp()
        'core:select-down': => @editor.selectDown()
        'core:select-to-top': => @editor.selectToTop()
        'core:select-to-bottom': => @editor.selectToBottom()
        'core:select-page-up': => @editor.selectUp(@getPageRows())
        'core:select-page-down': => @editor.selectDown(@getPageRows())
        'editor:indent': => @editor.indent()
        'editor:auto-indent': => @editor.autoIndentSelectedRows()
        'editor:indent-selected-rows': => @editor.indentSelectedRows()
        'editor:outdent-selected-rows': => @editor.outdentSelectedRows()
        'editor:newline': => @editor.insertNewline()
        'editor:newline-below': => @editor.insertNewlineBelow()
        'editor:newline-above': => @editor.insertNewlineAbove()
        'editor:add-selection-below': => @editor.addSelectionBelow()
        'editor:add-selection-above': => @editor.addSelectionAbove()
        'editor:split-selections-into-lines': => @editor.splitSelectionsIntoLines()
        'editor:toggle-soft-tabs': => @toggleSoftTabs()
        'editor:toggle-soft-wrap': => @toggleSoftWrap()
        'editor:fold-all': => @editor.foldAll()
        'editor:unfold-all': => @editor.unfoldAll()
        'editor:fold-current-row': => @editor.foldCurrentRow()
        'editor:unfold-current-row': => @editor.unfoldCurrentRow()
        'editor:fold-selection': => @editor.foldSelectedLines()
        'editor:fold-at-indent-level-1': => @editor.foldAllAtIndentLevel(0)
        'editor:fold-at-indent-level-2': => @editor.foldAllAtIndentLevel(1)
        'editor:fold-at-indent-level-3': => @editor.foldAllAtIndentLevel(2)
        'editor:fold-at-indent-level-4': => @editor.foldAllAtIndentLevel(3)
        'editor:fold-at-indent-level-5': => @editor.foldAllAtIndentLevel(4)
        'editor:fold-at-indent-level-6': => @editor.foldAllAtIndentLevel(5)
        'editor:fold-at-indent-level-7': => @editor.foldAllAtIndentLevel(6)
        'editor:fold-at-indent-level-8': => @editor.foldAllAtIndentLevel(7)
        'editor:fold-at-indent-level-9': => @editor.foldAllAtIndentLevel(8)
        'editor:toggle-line-comments': => @toggleLineCommentsInSelection()
        'editor:log-cursor-scope': => @logCursorScope()
        'editor:checkout-head-revision': => atom.project.getRepo()?.checkoutHeadForEditor(@editor)
        'editor:copy-path': => @copyPathToClipboard()
        'editor:move-line-up': => @editor.moveLineUp()
        'editor:move-line-down': => @editor.moveLineDown()
        'editor:duplicate-lines': => @editor.duplicateLines()
        'editor:join-lines': => @editor.joinLines()
        'editor:toggle-indent-guide': -> atom.config.toggle('editor.showIndentGuide')
        'editor:toggle-line-numbers': ->  atom.config.toggle('editor.showLineNumbers')
        'editor:scroll-to-cursor': => @scrollToCursorPosition()

    documentation = {}
    for name, method of editorBindings
      do (name, method) =>
        @command name, (e) -> method(e); false

  # Public: Get the underlying editor model for this view.
  #
  # Returns an {Editor}.
  getEditor: ->
    @editor

  # {Delegates to: Editor.getText}
  getText: ->
    @editor.getText()

  # {Delegates to: Editor.setText}
  setText: (text) ->
    @editor.setText(text)

  # {Delegates to: Editor.insertText}
  insertText: (text, options) ->
    @editor.insertText(text, options)

  setHeightInLines: (heightInLines) ->
    heightInLines ?= @calculateHeightInLines()
    @heightInLines = heightInLines if heightInLines

  # {Delegates to: Editor.setEditorWidthInChars}
  setWidthInChars: (widthInChars) ->
    widthInChars ?= @calculateWidthInChars()
    @editor.setEditorWidthInChars(widthInChars) if widthInChars

  # Public: Emulates the "page down" key, where the last row of a buffer scrolls
  # to become the first.
  pageDown: ->
    newScrollTop = @scrollTop() + @scrollView[0].clientHeight
    @editor.moveCursorDown(@getPageRows())
    @scrollTop(newScrollTop,  adjustVerticalScrollbar: true)

  # Public: Emulates the "page up" key, where the frst row of a buffer scrolls
  # to become the last.
  pageUp: ->
    newScrollTop = @scrollTop() - @scrollView[0].clientHeight
    @editor.moveCursorUp(@getPageRows())
    @scrollTop(newScrollTop,  adjustVerticalScrollbar: true)

  # Gets the number of actual page rows existing in an editor.
  #
  # Returns a {Number}.
  getPageRows: ->
    Math.max(1, Math.ceil(@scrollView[0].clientHeight / @lineHeight))

  # Public: Set whether invisible characters are shown.
  #
  # showInvisibles - A {Boolean} which, if `true`, show invisible characters.
  setShowInvisibles: (showInvisibles) ->
    return if showInvisibles == @showInvisibles
    @showInvisibles = showInvisibles
    @resetDisplay()

  # Public: Defines which characters are invisible.
  #
  # invisibles - An {Object} defining the invisible characters:
  #   :eol   - The end of line invisible {String} (default: `\u00ac`).
  #   :space - The space invisible {String} (default: `\u00b7`).
  #   :tab   - The tab invisible {String} (default: `\u00bb`).
  #   :cr    - The carriage return invisible {String} (default: `\u00a4`).
  setInvisibles: (@invisibles={}) ->
    _.defaults @invisibles,
      eol: '\u00ac'
      space: '\u00b7'
      tab: '\u00bb'
      cr: '\u00a4'
    @resetDisplay()

  # Public: Sets whether you want to show the indentation guides.
  #
  # showIndentGuide - A {Boolean} you can set to `true` if you want to see the
  #                   indentation guides.
  setShowIndentGuide: (showIndentGuide) ->
    return if showIndentGuide == @showIndentGuide
    @showIndentGuide = showIndentGuide
    @resetDisplay()

  # Public: Set the text to appear in the editor when it is empty.
  #
  # This only affects mini editors.
  #
  # placeholderText - A {String} of text to display when empty.
  setPlaceholderText: (placeholderText) ->
    return unless @mini
    @placeholderText = placeholderText
    @requestDisplayUpdate()

  getPlaceholderText: ->
    @placeholderText

  configure: ->
    @subscribe atom.config.observe 'editor.showLineNumbers', (showLineNumbers) => @gutter.setShowLineNumbers(showLineNumbers)
    @subscribe atom.config.observe 'editor.showInvisibles', (showInvisibles) => @setShowInvisibles(showInvisibles)
    @subscribe atom.config.observe 'editor.showIndentGuide', (showIndentGuide) => @setShowIndentGuide(showIndentGuide)
    @subscribe atom.config.observe 'editor.invisibles', (invisibles) => @setInvisibles(invisibles)
    @subscribe atom.config.observe 'editor.fontSize', (fontSize) => @setFontSize(fontSize)
    @subscribe atom.config.observe 'editor.fontFamily', (fontFamily) => @setFontFamily(fontFamily)
    @subscribe atom.config.observe 'editor.lineHeight', (lineHeight) => @setLineHeight(lineHeight)

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
      return unless e.which is 1 # only handle the left mouse button

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

    @gutter.on 'mousedown', '.foldable .icon-right', (e) =>
      bufferRow = $(e.target).parent().data('bufferRow')
      @editor.toggleFoldAtBufferRow(bufferRow)
      false

    @renderedLines.on 'mousedown', (e) =>
      clickCount = e.originalEvent.detail

      screenPosition = @screenPositionFromMouseEvent(e)
      if clickCount == 1
        if e.metaKey or (process.platform isnt 'darwin' and e.ctrlKey)
          @editor.addCursorAtScreenPosition(screenPosition)
        else if e.shiftKey
          @editor.selectToScreenPosition(screenPosition)
        else
          @editor.setCursorScreenPosition(screenPosition)
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

    @subscribe atom.themes, 'stylesheets-changed', => @recalculateDimensions()

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
      selectedText = @editor.getSelectedText()
      @hiddenInput.css('width', '100%')
    @hiddenInput.on 'compositionupdate', (e) =>
      @editor.insertText(e.originalEvent.data, {select: true, undo: 'skip'})
    @hiddenInput.on 'compositionend', =>
      @editor.insertText(selectedText, {select: true, undo: 'skip'})
      @hiddenInput.css('width', '1px')

    lastInput = ''
    @on "textInput", (e) =>
      # Work around of the accented character suggestion feature in OS X.
      selectedLength = @hiddenInput[0].selectionEnd - @hiddenInput[0].selectionStart
      if selectedLength is 1 and lastInput is @hiddenInput.val()
        @editor.selectLeft()

      lastInput = e.originalEvent.data
      @editor.insertText(lastInput)

      if lastInput is ' '
        true # Prevents parent elements from scrolling when a space is typed
      else
        @hiddenInput.val(lastInput)
        false

    # Ignore paste event, on Linux is wrongly emitted when user presses ctrl-v.
    @on "paste", -> false

  bringHiddenInputIntoView: ->
    @hiddenInput.css(top: @scrollTop(), left: @scrollLeft())

  selectOnMousemoveUntilMouseup: ->
    lastMoveEvent = null

    finalizeSelections = =>
      clearInterval(interval)
      $(document).off 'mousemove', moveHandler
      $(document).off 'mouseup', finalizeSelections

      unless @editor.isDestroyed()
        @editor.mergeIntersectingSelections(reversed: @editor.getLastSelection().isReversed())
        @editor.finalizeSelections()
        @syncCursorAnimations()

    moveHandler = (event = lastMoveEvent) =>
      return unless event?

      if event.which is 1 and @[0].style.display isnt 'none'
        @editor.selectToScreenPosition(@screenPositionFromMouseEvent(event))
        lastMoveEvent = event
      else
        finalizeSelections()

    $(document).on "mousemove.editor-#{@id}", moveHandler
    interval = setInterval(moveHandler, 20)
    $(document).one "mouseup.editor-#{@id}", finalizeSelections

  afterAttach: (onDom) ->
    return unless onDom

    # TODO: Remove this guard when we understand why this is happening
    unless @editor.isAlive()
      if atom.isReleasedVersion()
        return
      else
        throw new Error("Assertion failure: EditorView is getting attached to a dead editor. Why?")

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
      @saveScrollPositionForEditor()
      @unsubscribe(@editor)

    @editor = editor

    return unless @editor?

    @editor.setVisible(true)

    @subscribe @editor, "destroyed", =>
      @remove()

    @subscribe @editor, "contents-conflicted", =>
      @showBufferConflictAlert(@editor)

    @subscribe @editor, "path-changed", =>
      @trigger 'editor:path-changed'

    @subscribe @editor, "grammar-changed", =>
      @trigger 'editor:grammar-changed'

    @subscribe @editor, 'selection-added', (selection) =>
      @newCursors.push(selection.cursor)
      @newSelections.push(selection)
      @requestDisplayUpdate()

    @subscribe @editor, 'screen-lines-changed', (e) =>
      @handleScreenLinesChange(e)

    @subscribe @editor, 'scroll-top-changed', (scrollTop) =>
      @scrollTop(scrollTop)

    @subscribe @editor, 'scroll-left-changed', (scrollLeft) =>
      @scrollView.scrollLeft(scrollLeft)

    @subscribe @editor, 'soft-wrap-changed', (softWrap) =>
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

  # Public: Scrolls the editor to the bottom.
  scrollToBottom: ->
    @scrollBottom(@editor.getScreenLineCount() * @lineHeight)

  # Public: Scrolls the editor to the position of the most recently added
  # cursor if it isn't current on screen.
  #
  # The editor is centered around the cursor's position if possible.
  scrollToCursorPosition: ->
    @scrollToBufferPosition(@editor.getCursorBufferPosition(), center: true)

  # Public: Scrolls the editor to the given buffer position.
  #
  # bufferPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash matching the options available to {::scrollToPixelPosition}
  scrollToBufferPosition: (bufferPosition, options) ->
    @scrollToPixelPosition(@pixelPositionForBufferPosition(bufferPosition), options)

  # Public: Scrolls the editor to the given screen position.
  #
  # screenPosition - An object that represents a buffer position. It can be either
  #                  an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  # options - A hash matching the options available to {::scrollToPixelPosition}
  scrollToScreenPosition: (screenPosition, options) ->
    @scrollToPixelPosition(@pixelPositionForScreenPosition(screenPosition), options)

  # Public: Scrolls the editor to the given pixel position.
  #
  # pixelPosition - An object that represents a pixel position. It can be either
  #                 an {Object} (`{row, column}`), {Array} (`[row, column]`), or
  #                 {Point}.
  # options - A hash with the following keys:
  #   :center - if `true`, the position is scrolled such that it's in
  #             the center of the editor
  scrollToPixelPosition: (pixelPosition, options) ->
    return unless @attached
    @scrollVertically(pixelPosition, options)
    @scrollHorizontally(pixelPosition)

  # Public: Highlight all the folds within the given buffer range.
  #
  # "Highlighting" essentially just adds the `fold-selected` class to the line's
  # DOM element.
  #
  # bufferRange - The {Range} to check.
  highlightFoldsContainingBufferRange: (bufferRange) ->
    screenLines = @editor.linesForScreenRows(@firstRenderedScreenRow, @lastRenderedScreenRow)
    for screenLine, i in screenLines
      if fold = screenLine.fold
        screenRow = @firstRenderedScreenRow + i
        element = @lineElementForScreenRow(screenRow)

        if bufferRange.intersectsWith(fold.getBufferRange())
          element.addClass('fold-selected')
        else
          element.removeClass('fold-selected')

  saveScrollPositionForEditor: ->
    if @attached
      @editor.setScrollTop(@scrollTop())
      @editor.setScrollLeft(@scrollLeft())

  # Public: Toggle soft tabs on the edit session.
  toggleSoftTabs: ->
    @editor.setSoftTabs(not @editor.getSoftTabs())

  # Public: Toggle soft wrap on the edit session.
  toggleSoftWrap: ->
    @setWidthInChars()
    @editor.setSoftWrap(not @editor.getSoftWrap())

  calculateWidthInChars: ->
    Math.floor((@scrollView.width() - @getScrollbarWidth()) / @charWidth)

  calculateHeightInLines: ->
    Math.ceil($(window).height() / @lineHeight)

  getScrollbarWidth: ->
    scrollbarElement = @verticalScrollbar[0]
    scrollbarElement.offsetWidth - scrollbarElement.clientWidth

  # Public: Enables/disables soft wrap on the editor.
  #
  # softWrap - A {Boolean} which, if `true`, enables soft wrap
  setSoftWrap: (softWrap) ->
    if softWrap
      @addClass 'soft-wrap'
      @scrollLeft(0)
    else
      @removeClass 'soft-wrap'

  # Public: Sets the font size for the editor.
  #
  # fontSize - A {Number} indicating the font size in pixels.
  setFontSize: (fontSize) ->
    @css('font-size', "#{fontSize}px")

    @clearCharacterWidthCache()

    if @isOnDom()
      @redraw()
    else
      @redrawOnReattach = @attached

  # Public: Retrieves the font size for the editor.
  #
  # Returns a {Number} indicating the font size in pixels.
  getFontSize: ->
    parseInt(@css("font-size"))

  # Public: Sets the font family for the editor.
  #
  # fontFamily - A {String} identifying the CSS `font-family`.
  setFontFamily: (fontFamily='') ->
    @css('font-family', fontFamily)

    @clearCharacterWidthCache()

    @redraw()

  # Public: Gets the font family for the editor.
  #
  # Returns a {String} identifying the CSS `font-family`.
  getFontFamily: -> @css("font-family")

  # Public: Sets the line height of the editor.
  #
  # Calling this method has no effect when called on a mini editor.
  #
  # lineHeight - A {Number} without a unit suffix identifying the CSS
  # `line-height`.
  setLineHeight: (lineHeight) ->
    return if @mini
    @css('line-height', lineHeight)
    @redraw()

  # Public: Redraw the editor
  redraw: ->
    return unless @hasParent()
    return unless @attached
    @redrawOnReattach = false
    @calculateDimensions()
    @updatePaddingOfRenderedLines()
    @updateLayerDimensions()
    @requestDisplayUpdate()

  # Public: Split the editor view left.
  splitLeft: ->
    pane = @getPane()
    pane?.splitLeft(pane?.copyActiveItem()).activeView

  # Public: Split the editor view right.
  splitRight: ->
    pane = @getPane()
    pane?.splitRight(pane?.copyActiveItem()).activeView

  # Public: Split the editor view up.
  splitUp: ->
    pane = @getPane()
    pane?.splitUp(pane?.copyActiveItem()).activeView

  # Public: Split the editor view down.
  splitDown: ->
    pane = @getPane()
    pane?.splitDown(pane?.copyActiveItem()).activeView

  # Public: Get this view's pane.
  #
  # Returns a {Pane}.
  getPane: ->
    @parent('.item-views').parents('.pane').view()

  remove: (selector, keepData) ->
    return super if keepData or @removed
    super
    atom.workspaceView?.focus()

  beforeRemove: ->
    @trigger 'editor:will-be-removed'
    @removed = true
    @editor?.destroy()
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
    @saveScrollPositionForEditor()

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

  recalculateDimensions: ->
    return unless @attached and @isVisible()

    oldCharWidth = @charWidth
    oldLineHeight = @lineHeight

    @calculateDimensions()

    unless @charWidth is oldCharWidth and @lineHeight is oldLineHeight
      @clearCharacterWidthCache()
      @requestDisplayUpdate()

  updateLayerDimensions: (scrollViewWidth) ->
    height = @lineHeight * @editor.getScreenLineCount()
    unless @layerHeight == height
      @layerHeight = height
      @underlayer.height(@layerHeight)
      @renderedLines.height(@layerHeight)
      @overlayer.height(@layerHeight)
      @verticalScrollbarContent.height(@layerHeight)
      @scrollBottom(height) if @scrollBottom() > height

    minWidth = Math.max(@charWidth * @editor.getMaxScreenLineLength() + 20, scrollViewWidth)
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
    @newCursors = @editor.getCursors()
    @newSelections = @editor.getSelections()
    @updateDisplay(suppressAutoscroll: true)

  requestDisplayUpdate: ->
    return if @pendingDisplayUpdate
    return unless @isVisible()
    @pendingDisplayUpdate = true
    setImmediate =>
      @updateDisplay()
      @pendingDisplayUpdate = false

  updateDisplay: (options) ->
    return unless @attached and @editor
    return if @editor.isDestroyed()
    unless @isOnDom() and @isVisible()
      @redrawOnReattach = true
      return

    scrollViewWidth = @scrollView.width()
    @updateRenderedLines(scrollViewWidth)
    @updatePlaceholderText()
    @highlightCursorLine()
    @updateCursorViews()
    @updateSelectionViews()
    @autoscroll(options?.suppressAutoscroll ? false)
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
    cursorView.resetBlinking() for cursorView in @getCursorViews()

  autoscroll: (suppressAutoscroll) ->
    for cursorView in @getCursorViews()
      if !suppressAutoscroll and cursorView.needsAutoscroll()
        @scrollToPixelPosition(cursorView.getPixelPosition())
      cursorView.clearAutoscroll()

    for selectionView in @getSelectionViews()
      if !suppressAutoscroll and selectionView.needsAutoscroll()
        @scrollToPixelPosition(selectionView.getCenterPixelPosition(), center: true)
        selectionView.highlight()
      selectionView.clearAutoscroll()

  updatePlaceholderText: ->
    return unless @mini
    if (not @placeholderText) or @editor.getText()
      @find('.placeholder-text').remove()
    else if @placeholderText and not @editor.getText()
      element = @find('.placeholder-text')
      if element.length
        element.text(@placeholderText)
      else
        @underlayer.append($('<span/>', class: 'placeholder-text', text: @placeholderText))

  updateRenderedLines: (scrollViewWidth) ->
    firstVisibleScreenRow = @getFirstVisibleScreenRow()
    lastScreenRowToRender = firstVisibleScreenRow + @heightInLines - 1
    lastScreenRow = @editor.getLastScreenRow()

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
    @updateLayerDimensions(scrollViewWidth)
    @updatePaddingOfRenderedLines()

  computeSurroundingEmptyLineChanges: (change) ->
    emptyLineChanges = []

    if change.bufferDelta?
      afterStart = change.end + change.bufferDelta + 1
      if @editor.lineForBufferRow(afterStart) is ''
        afterEnd = afterStart
        afterEnd++ while @editor.lineForBufferRow(afterEnd + 1) is ''
        emptyLineChanges.push({start: afterStart, end: afterEnd, screenDelta: 0})

      beforeEnd = change.start - 1
      if @editor.lineForBufferRow(beforeEnd) is ''
        beforeStart = beforeEnd
        beforeStart-- while @editor.lineForBufferRow(beforeStart - 1) is ''
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

    paddingBottom = (@editor.getLastScreenRow() - @lastRenderedScreenRow) * @lineHeight
    @renderedLines.css('padding-bottom', paddingBottom)
    @gutter.lineNumbers.css('padding-bottom', paddingBottom)

  # Public: Retrieves the number of the row that is visible and currently at the
  # top of the editor.
  #
  # Returns a {Number}.
  getFirstVisibleScreenRow: ->
    screenRow = Math.floor(@scrollTop() / @lineHeight)
    screenRow = 0 if isNaN(screenRow)
    screenRow

  # Public: Retrieves the number of the row that is visible and currently at the
  # bottom of the editor.
  #
  # Returns a {Number}.
  getLastVisibleScreenRow: ->
    calculatedRow = Math.ceil((@scrollTop() + @scrollView.height()) / @lineHeight) - 1
    screenRow = Math.max(0, Math.min(@editor.getScreenLineCount() - 1, calculatedRow))
    screenRow = 0 if isNaN(screenRow)
    screenRow

  # Public: Given a row number, identifies if it is currently visible.
  #
  # row - A row {Number} to check
  #
  # Returns a {Boolean}.
  isScreenRowVisible: (row) ->
    @getFirstVisibleScreenRow() <= row <= @getLastVisibleScreenRow()

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

  # Public: Converts a buffer position to a pixel position.
  #
  # position - An object that represents a buffer position. It can be either
  #            an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an object with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForBufferPosition: (position) ->
    @pixelPositionForScreenPosition(@editor.screenPositionForBufferPosition(position))

  # Public: Converts a screen position to a pixel position.
  #
  # position - An object that represents a screen position. It can be either
  #            an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
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

    tokenizedLine = @editor.displayBuffer.lineForRow(screenRow)
    textContent = lineElement.textContent

    left = 0
    index = 0
    for token in tokenizedLine.tokens
      for bufferChar in token.value
        return left if index >= screenColumn

        # Invisibles might cause renderedChar to be different than bufferChar
        renderedChar = textContent[index]
        val = @getCharacterWidthCache(token.scopes, renderedChar)
        if val?
          left += val
        else
          return @measureToColumn(lineElement, tokenizedLine, screenColumn)

        index++
    left

  measureToColumn: (lineElement, tokenizedLine, screenColumn) ->
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

        scopes = tokenizedLine.tokenAtBufferColumn(index)?.scopes
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

  getCharacterWidthCache: (scopes, char) ->
    scopes ?= NoScope
    obj = @constructor.characterWidthCache
    for scope in scopes
      obj = obj[scope]
      return null unless obj?
    obj[char]

  setCharacterWidthCache: (scopes, char, val) ->
    scopes ?= NoScope
    obj = @constructor.characterWidthCache
    for scope in scopes
      obj[scope] ?= {}
      obj = obj[scope]
    obj[char] = val

  clearCharacterWidthCache: ->
    @constructor.characterWidthCache = {}

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
    if @editor.getSelection().isEmpty()
      @highlightedLine = @lineElementForScreenRow(@editor.getCursorScreenRow())
      @highlightedLine.addClass('cursor-line')
    else
      @highlightedLine = null

  # Copies the current file path to the native clipboard.
  copyPathToClipboard: ->
    path = @editor.getPath()
    atom.clipboard.write(path) if path?

  @buildLineHtml: ({tokens, text, lineEnding, fold, isSoftWrapped, invisibles, eolInvisibles, htmlEolInvisibles, attributes, showIndentGuide, indentation, editor, mini}) ->
    scopeStack = []
    line = []

    attributePairs = ''
    attributePairs += " #{attributeName}=\"#{value}\"" for attributeName, value of attributes
    line.push("<div #{attributePairs}>")

    if text == ''
      html = @buildEmptyLineHtml(showIndentGuide, eolInvisibles, htmlEolInvisibles, indentation, editor, mini)
      line.push(html) if html
    else
      firstTrailingWhitespacePosition = text.search(/\s*$/)
      lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
      position = 0
      for token in tokens
        @updateScopeStack(line, scopeStack, token.scopes)
        hasIndentGuide = not mini and showIndentGuide and (token.hasLeadingWhitespace() or (token.hasTrailingWhitespace() and lineIsWhitespaceOnly))
        line.push(token.getValueAsHtml({invisibles, hasIndentGuide}))
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
    line.push("<span class=\"#{scope.replace(/\.+/g, ' ')}\">")

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
    selection = @editor.getSelection()
    return false if selection.isEmpty()

    text = replaceFn(@editor.getTextInRange(selection.getBufferRange()))
    return false if text is null or text is undefined

    @editor.insertText(text, select: true)
    true

  consolidateSelections: (e) -> e.abortKeyBinding() unless @editor.consolidateSelections()

  logCursorScope: ->
    console.log @editor.getCursorScopes()

  logScreenLines: (start, end) ->
    @editor.logScreenLines(start, end)

  logRenderedLines: ->
    @renderedLines.find('.line').each (n) ->
      console.log n, $(this).text()
