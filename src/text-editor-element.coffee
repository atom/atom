{Emitter} = require 'event-kit'
Path = require 'path'
{defaults} = require 'underscore-plus'
TextBuffer = require 'text-buffer'
TextEditor = require './text-editor'
TextEditorComponent = require './text-editor-component'

ShadowStyleSheet = null

class TextEditorElement extends HTMLElement
  model: null
  componentDescriptor: null
  component: null
  attached: false
  tileSize: null
  focusOnAttach: false
  hasTiledRendering: true

  createdCallback: ->
    @emitter = new Emitter
    @initializeContent()
    @addEventListener 'focus', @focused.bind(this)
    @addEventListener 'blur', @blurred.bind(this)

  initializeContent: (attributes) ->
    @classList.add('editor')
    @setAttribute('tabindex', -1)

    if atom.config.get('editor.useShadowDOM')
      @useShadowDOM = true

      unless ShadowStyleSheet?
        ShadowStyleSheet = document.createElement('style')
        ShadowStyleSheet.textContent = atom.themes.loadLessStylesheet(require.resolve('../static/text-editor-shadow.less'))

      @createShadowRoot()

      @shadowRoot.appendChild(ShadowStyleSheet.cloneNode(true))
      @stylesElement = document.createElement('atom-styles')
      @stylesElement.setAttribute('context', 'atom-text-editor')
      @stylesElement.initialize()

      @rootElement = document.createElement('div')
      @rootElement.classList.add('editor--private')

      @shadowRoot.appendChild(@stylesElement)
      @shadowRoot.appendChild(@rootElement)
    else
      @useShadowDOM = false

      @classList.add('editor', 'editor-colors')
      @stylesElement = document.head.querySelector('atom-styles')
      @rootElement = this

  attachedCallback: ->
    @buildModel() unless @getModel()?
    atom.assert(@model.isAlive(), "Attaching a view for a destroyed editor")
    @mountComponent() unless @component?
    @component.checkForVisibilityChange()
    if this is document.activeElement
      @focused()
    @emitter.emit("did-attach")

  detachedCallback: ->
    @unmountComponent()
    @emitter.emit("did-detach")

  initialize: (model) ->
    @setModel(model)
    this

  setModel: (model) ->
    throw new Error("Model already assigned on TextEditorElement") if @model?
    return if model.isDestroyed()

    @model = model
    @mountComponent()
    @addGrammarScopeAttribute()
    @addMiniAttribute() if @model.isMini()
    @addEncodingAttribute()
    @model.onDidChangeGrammar => @addGrammarScopeAttribute()
    @model.onDidChangeEncoding => @addEncodingAttribute()
    @model.onDidDestroy => @unmountComponent()
    @model.onDidChangeMini (mini) => if mini then @addMiniAttribute() else @removeMiniAttribute()
    @model

  getModel: ->
    @model ? @buildModel()

  buildModel: ->
    @setModel(new TextEditor(
      buffer: new TextBuffer(@textContent)
      softWrapped: false
      tabLength: 2
      softTabs: true
      mini: @hasAttribute('mini')
      lineNumberGutterVisible: not @hasAttribute('gutter-hidden')
      placeholderText: @getAttribute('placeholder-text')
    ))

  mountComponent: ->
    @component = new TextEditorComponent(
      hostElement: this
      rootElement: @rootElement
      stylesElement: @stylesElement
      editor: @model
      tileSize: @tileSize
      useShadowDOM: @useShadowDOM
    )
    @rootElement.appendChild(@component.getDomNode())

    if @useShadowDOM
      @shadowRoot.addEventListener('blur', @shadowRootBlurred.bind(this), true)
    else
      inputNode = @component.hiddenInputComponent.getDomNode()
      inputNode.addEventListener 'focus', @focused.bind(this)
      inputNode.addEventListener 'blur', => @dispatchEvent(new FocusEvent('blur', bubbles: false))

  unmountComponent: ->
    if @component?
      @component.destroy()
      @component.getDomNode().remove()
      @component = null

  focused: ->
    @component?.focused()

  blurred: (event) ->
    unless @useShadowDOM
      if event.relatedTarget is @component.hiddenInputComponent.getDomNode()
        event.stopImmediatePropagation()
        return

    @component?.blurred()

  # Work around what seems to be a bug in Chromium. Focus can be stolen from the
  # hidden input when clicking on the gutter and transferred to the
  # already-focused host element. The host element never gets a 'focus' event
  # however, which leaves us in a limbo state where the text editor element is
  # focused but the hidden input isn't focused. This always refocuses the hidden
  # input if a blur event occurs in the shadow DOM that is transferring focus
  # back to the host element.
  shadowRootBlurred: (event) ->
    @component.focused() if event.relatedTarget is this

  addGrammarScopeAttribute: ->
    @dataset.grammar = @model.getGrammar()?.scopeName?.replace(/\./g, ' ')

  addMiniAttribute: ->
    @setAttributeNode(document.createAttribute("mini"))

  removeMiniAttribute: ->
    @removeAttribute("mini")

  addEncodingAttribute: ->
    @dataset.encoding = @model.getEncoding()

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

  setUpdatedSynchronously: (@updatedSynchronously) -> @updatedSynchronously

  isUpdatedSynchronously: -> @updatedSynchronously

  # Extended: Continuously reflows lines and line numbers. (Has performance overhead)
  #
  # `continuousReflow` A {Boolean} indicating whether to keep reflowing or not.
  setContinuousReflow: (continuousReflow) ->
    @component?.setContinuousReflow(continuousReflow)

  # Extended: get the width of a character of text displayed in this element.
  #
  # Returns a {Number} of pixels.
  getDefaultCharacterWidth: ->
    @getModel().getDefaultCharWidth()

  # Extended: Converts a buffer position to a pixel position.
  #
  # * `bufferPosition` An object that represents a buffer position. It can be either
  #   an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an {Object} with two values: `top` and `left`, representing the pixel position.
  pixelPositionForBufferPosition: (bufferPosition) ->
    @component.pixelPositionForBufferPosition(bufferPosition)

  # Extended: Converts a screen position to a pixel position.
  #
  # * `screenPosition` An object that represents a screen position. It can be either
  #   an {Object} (`{row, column}`), {Array} (`[row, column]`), or {Point}
  #
  # Returns an {Object} with two values: `top` and `left`, representing the pixel positions.
  pixelPositionForScreenPosition: (screenPosition) ->
    @component.pixelPositionForScreenPosition(screenPosition)

  # Extended: Retrieves the number of the row that is visible and currently at the
  # top of the editor.
  #
  # Returns a {Number}.
  getFirstVisibleScreenRow: ->
    @getVisibleRowRange()[0]

  # Extended: Retrieves the number of the row that is visible and currently at the
  # bottom of the editor.
  #
  # Returns a {Number}.
  getLastVisibleScreenRow: ->
    @getVisibleRowRange()[1]

  # Extended: call the given `callback` when the editor is attached to the DOM.
  #
  # * `callback` {Function}
  onDidAttach: (callback) ->
    @emitter.on("did-attach", callback)

  # Extended: call the given `callback` when the editor is detached from the DOM.
  #
  # * `callback` {Function}
  onDidDetach: (callback) ->
    @emitter.on("did-detach", callback)

  onDidChangeScrollTop: (callback) ->
    @component.onDidChangeScrollTop(callback)

  onDidChangeScrollLeft: (callback) ->
    @component.onDidChangeScrollLeft(callback)

  setScrollLeft: (scrollLeft) ->
    @component.setScrollLeft(scrollLeft)

  setScrollRight: (scrollRight) ->
    @component.setScrollRight(scrollRight)

  setScrollTop: (scrollTop) ->
    @component.setScrollTop(scrollTop)

  setScrollBottom: (scrollBottom) ->
    @component.setScrollBottom(scrollBottom)

  # Essential: Scrolls the editor to the top
  scrollToTop: ->
    @setScrollTop(0)

  # Essential: Scrolls the editor to the bottom
  scrollToBottom: ->
    @setScrollBottom(Infinity)

  getScrollTop: ->
    @component.getScrollTop()

  getScrollLeft: ->
    @component.getScrollLeft()

  getScrollRight: ->
    @component.getScrollRight()

  getScrollBottom: ->
    @component.getScrollBottom()

  getScrollHeight: ->
    @component.getScrollHeight()

  getScrollWidth: ->
    @component.getScrollWidth()

  getVerticalScrollbarWidth: ->
    @component.getVerticalScrollbarWidth()

  getHorizontalScrollbarHeight: ->
    @component.getHorizontalScrollbarHeight()

  getVisibleRowRange: ->
    @component.getVisibleRowRange()

  intersectsVisibleRowRange: (startRow, endRow) ->
    [visibleStart, visibleEnd] = @getVisibleRowRange()
    not (endRow <= visibleStart or visibleEnd <= startRow)

  selectionIntersectsVisibleRowRange: (selection) ->
    {start, end} = selection.getScreenRange()
    @intersectsVisibleRowRange(start.row, end.row + 1)

  screenPositionForPixelPosition: (pixelPosition) ->
    @component.screenPositionForPixelPosition(pixelPosition)

  pixelRectForScreenRange: (screenRange) ->
    @component.pixelRectForScreenRange(screenRange)

  pixelRangeForScreenRange: (screenRange) ->
    @component.pixelRangeForScreenRange(screenRange)

  setWidth: (width) ->
    @style.width = (@component.getGutterWidth() + width) + "px"
    @component.measureDimensions()

  getWidth: ->
    @offsetWidth - @component.getGutterWidth()

  setHeight: (height) ->
    @style.height = height + "px"
    @component.measureDimensions()

  getHeight: ->
    @offsetHeight

stopEventPropagation = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        commandListener.call(@getModel(), event)
  newCommandListeners

stopEventPropagationAndGroupUndo = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        model = @getModel()
        model.transact atom.config.get('editor.undoGroupingInterval'), ->
          commandListener.call(model, event)
  newCommandListeners

atom.commands.add 'atom-text-editor', stopEventPropagation(
  'core:undo': -> @undo()
  'core:redo': -> @redo()
  'core:move-left': -> @moveLeft()
  'core:move-right': -> @moveRight()
  'core:select-left': -> @selectLeft()
  'core:select-right': -> @selectRight()
  'core:select-up': -> @selectUp()
  'core:select-down': -> @selectDown()
  'core:select-all': -> @selectAll()
  'editor:select-word': -> @selectWordsContainingCursors()
  'editor:consolidate-selections': (event) -> event.abortKeyBinding() unless @consolidateSelections()
  'editor:move-to-beginning-of-next-paragraph': -> @moveToBeginningOfNextParagraph()
  'editor:move-to-beginning-of-previous-paragraph': -> @moveToBeginningOfPreviousParagraph()
  'editor:move-to-beginning-of-screen-line': -> @moveToBeginningOfScreenLine()
  'editor:move-to-beginning-of-line': -> @moveToBeginningOfLine()
  'editor:move-to-end-of-screen-line': -> @moveToEndOfScreenLine()
  'editor:move-to-end-of-line': -> @moveToEndOfLine()
  'editor:move-to-first-character-of-line': -> @moveToFirstCharacterOfLine()
  'editor:move-to-beginning-of-word': -> @moveToBeginningOfWord()
  'editor:move-to-end-of-word': -> @moveToEndOfWord()
  'editor:move-to-beginning-of-next-word': -> @moveToBeginningOfNextWord()
  'editor:move-to-previous-word-boundary': -> @moveToPreviousWordBoundary()
  'editor:move-to-next-word-boundary': -> @moveToNextWordBoundary()
  'editor:move-to-previous-subword-boundary': -> @moveToPreviousSubwordBoundary()
  'editor:move-to-next-subword-boundary': -> @moveToNextSubwordBoundary()
  'editor:select-to-beginning-of-next-paragraph': -> @selectToBeginningOfNextParagraph()
  'editor:select-to-beginning-of-previous-paragraph': -> @selectToBeginningOfPreviousParagraph()
  'editor:select-to-end-of-line': -> @selectToEndOfLine()
  'editor:select-to-beginning-of-line': -> @selectToBeginningOfLine()
  'editor:select-to-end-of-word': -> @selectToEndOfWord()
  'editor:select-to-beginning-of-word': -> @selectToBeginningOfWord()
  'editor:select-to-beginning-of-next-word': -> @selectToBeginningOfNextWord()
  'editor:select-to-next-word-boundary': -> @selectToNextWordBoundary()
  'editor:select-to-previous-word-boundary': -> @selectToPreviousWordBoundary()
  'editor:select-to-next-subword-boundary': -> @selectToNextSubwordBoundary()
  'editor:select-to-previous-subword-boundary': -> @selectToPreviousSubwordBoundary()
  'editor:select-to-first-character-of-line': -> @selectToFirstCharacterOfLine()
  'editor:select-line': -> @selectLinesContainingCursors()
)

atom.commands.add 'atom-text-editor', stopEventPropagationAndGroupUndo(
  'core:backspace': -> @backspace()
  'core:delete': -> @delete()
  'core:cut': -> @cutSelectedText()
  'core:copy': -> @copySelectedText()
  'core:paste': -> @pasteText()
  'editor:delete-to-previous-word-boundary': -> @deleteToPreviousWordBoundary()
  'editor:delete-to-next-word-boundary': -> @deleteToNextWordBoundary()
  'editor:delete-to-beginning-of-word': -> @deleteToBeginningOfWord()
  'editor:delete-to-beginning-of-line': -> @deleteToBeginningOfLine()
  'editor:delete-to-end-of-line': -> @deleteToEndOfLine()
  'editor:delete-to-end-of-word': -> @deleteToEndOfWord()
  'editor:delete-to-beginning-of-subword': -> @deleteToBeginningOfSubword()
  'editor:delete-to-end-of-subword': -> @deleteToEndOfSubword()
  'editor:delete-line': -> @deleteLine()
  'editor:cut-to-end-of-line': -> @cutToEndOfLine()
  'editor:cut-to-end-of-buffer-line': -> @cutToEndOfBufferLine()
  'editor:transpose': -> @transpose()
  'editor:upper-case': -> @upperCase()
  'editor:lower-case': -> @lowerCase()
  'editor:copy-selection': -> @copyOnlySelectedText()
)

atom.commands.add 'atom-text-editor:not([mini])', stopEventPropagation(
  'core:move-up': -> @moveUp()
  'core:move-down': -> @moveDown()
  'core:move-to-top': -> @moveToTop()
  'core:move-to-bottom': -> @moveToBottom()
  'core:page-up': -> @pageUp()
  'core:page-down': -> @pageDown()
  'core:select-to-top': -> @selectToTop()
  'core:select-to-bottom': -> @selectToBottom()
  'core:select-page-up': -> @selectPageUp()
  'core:select-page-down': -> @selectPageDown()
  'editor:add-selection-below': -> @addSelectionBelow()
  'editor:add-selection-above': -> @addSelectionAbove()
  'editor:split-selections-into-lines': -> @splitSelectionsIntoLines()
  'editor:toggle-soft-tabs': -> @toggleSoftTabs()
  'editor:toggle-soft-wrap': -> @toggleSoftWrapped()
  'editor:fold-all': -> @foldAll()
  'editor:unfold-all': -> @unfoldAll()
  'editor:fold-current-row': -> @foldCurrentRow()
  'editor:unfold-current-row': -> @unfoldCurrentRow()
  'editor:fold-selection': -> @foldSelectedLines()
  'editor:fold-at-indent-level-1': -> @foldAllAtIndentLevel(0)
  'editor:fold-at-indent-level-2': -> @foldAllAtIndentLevel(1)
  'editor:fold-at-indent-level-3': -> @foldAllAtIndentLevel(2)
  'editor:fold-at-indent-level-4': -> @foldAllAtIndentLevel(3)
  'editor:fold-at-indent-level-5': -> @foldAllAtIndentLevel(4)
  'editor:fold-at-indent-level-6': -> @foldAllAtIndentLevel(5)
  'editor:fold-at-indent-level-7': -> @foldAllAtIndentLevel(6)
  'editor:fold-at-indent-level-8': -> @foldAllAtIndentLevel(7)
  'editor:fold-at-indent-level-9': -> @foldAllAtIndentLevel(8)
  'editor:log-cursor-scope': -> @logCursorScope()
  'editor:copy-path': -> @copyPathToClipboard()
  'editor:toggle-indent-guide': -> atom.config.set('editor.showIndentGuide', not atom.config.get('editor.showIndentGuide'))
  'editor:toggle-line-numbers': -> atom.config.set('editor.showLineNumbers', not atom.config.get('editor.showLineNumbers'))
  'editor:scroll-to-cursor': -> @scrollToCursorPosition()
)

atom.commands.add 'atom-text-editor:not([mini])', stopEventPropagationAndGroupUndo(
  'editor:indent': -> @indent()
  'editor:auto-indent': -> @autoIndentSelectedRows()
  'editor:indent-selected-rows': -> @indentSelectedRows()
  'editor:outdent-selected-rows': -> @outdentSelectedRows()
  'editor:newline': -> @insertNewline()
  'editor:newline-below': -> @insertNewlineBelow()
  'editor:newline-above': -> @insertNewlineAbove()
  'editor:toggle-line-comments': -> @toggleLineCommentsInSelection()
  'editor:checkout-head-revision': -> @checkoutHeadRevision()
  'editor:move-line-up': -> @moveLineUp()
  'editor:move-line-down': -> @moveLineDown()
  'editor:duplicate-lines': -> @duplicateLines()
  'editor:join-lines': -> @joinLines()
)

module.exports = TextEditorElement = document.registerElement 'atom-text-editor', prototype: TextEditorElement.prototype
