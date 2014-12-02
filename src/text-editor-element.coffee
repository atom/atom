{View, $, callRemoveHooks} = require 'space-pen'
React = require 'react-atom-fork'
Path = require 'path'
{defaults} = require 'underscore-plus'
TextBuffer = require 'text-buffer'
TextEditor = require './text-editor'
TextEditorComponent = require './text-editor-component'
TextEditorView = null

ShadowStyleSheet = null

class TextEditorElement extends HTMLElement
  model: null
  componentDescriptor: null
  component: null
  lineOverdrawMargin: null
  focusOnAttach: false

  createdCallback: ->
    @initializeContent()
    @createSpacePenShim()
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

  createSpacePenShim: ->
    TextEditorView ?= require './text-editor-view'
    @__spacePenView = new TextEditorView(this)

  attachedCallback: ->
    @buildModel() unless @getModel()?
    @mountComponent() unless @component?.isMounted()
    @component.checkForVisibilityChange()
    @focus() if @focusOnAttach

  initialize: (model) ->
    @setModel(model)
    this

  setModel: (model) ->
    throw new Error("Model already assigned on TextEditorElement") if @model?
    return if model.isDestroyed()

    @model = model
    @mountComponent()
    @addGrammarScopeAttribute()
    @addMiniAttributeIfNeeded()
    @addEncodingAttribute()
    @model.onDidChangeGrammar => @addGrammarScopeAttribute()
    @model.onDidChangeEncoding => @addEncodingAttribute()
    @model.onDidDestroy => @unmountComponent()
    @__spacePenView.setModel(@model)
    @model

  getModel: ->
    @model ? @buildModel()

  buildModel: ->
    @setModel(new TextEditor(
      buffer: new TextBuffer
      softWrapped: false
      tabLength: 2
      softTabs: true
      mini: @hasAttribute('mini')
      placeholderText: @getAttribute('placeholder-text')
    ))

  mountComponent: ->
    @componentDescriptor ?= TextEditorComponent(
      hostElement: this
      rootElement: @rootElement
      stylesElement: @stylesElement
      editor: @model
      mini: @model.mini
      lineOverdrawMargin: @lineOverdrawMargin
      useShadowDOM: @useShadowDOM
    )
    @component = React.renderComponent(@componentDescriptor, @rootElement)

    if @useShadowDOM
      @shadowRoot.addEventListener('blur', @shadowRootBlurred.bind(this), true)
    else
      inputNode = @component.refs.input.getDOMNode()
      inputNode.addEventListener 'focus', @focused.bind(this)
      inputNode.addEventListener 'blur', => @dispatchEvent(new FocusEvent('blur', bubbles: false))

  unmountComponent: ->
    return unless @component?.isMounted()
    callRemoveHooks(this)
    React.unmountComponentAtNode(this)
    @component = null

  focused: ->
    if @component?
      @component.focused()
    else
      @focusOnAttach = true

  blurred: (event) ->
    unless @useShadowDOM
      if event.relatedTarget is @component?.refs.input?.getDOMNode()
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
    grammarScope = @model.getGrammar()?.scopeName?.replace(/\./g, ' ')
    @dataset.grammar = grammarScope

  addMiniAttributeIfNeeded: ->
    @setAttributeNode(document.createAttribute("mini")) if @model.isMini()

  addEncodingAttribute: ->
    @dataset.encoding = @model.getEncoding()

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

  setUpdatedSynchronously: (@updatedSynchronously) -> @updatedSynchronously

  isUpdatedSynchronously: -> @updatedSynchronously

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
)

atom.commands.add 'atom-text-editor', stopEventPropagationAndGroupUndo(
  'core:move-left': -> @moveLeft()
  'core:move-right': -> @moveRight()
  'core:select-left': -> @selectLeft()
  'core:select-right': -> @selectRight()
  'core:select-all': -> @selectAll()
  'core:backspace': -> @backspace()
  'core:delete': -> @delete()
  'core:cut': -> @cutSelectedText()
  'core:copy': -> @copySelectedText()
  'core:paste': -> @pasteText()
  'editor:move-to-previous-word': -> @moveToPreviousWord()
  'editor:select-word': -> @selectWordsContainingCursors()
  'editor:consolidate-selections': (event) -> event.abortKeyBinding() unless @consolidateSelections()
  'editor:delete-to-beginning-of-word': -> @deleteToBeginningOfWord()
  'editor:delete-to-beginning-of-line': -> @deleteToBeginningOfLine()
  'editor:delete-to-end-of-line': -> @deleteToEndOfLine()
  'editor:delete-to-end-of-word': -> @deleteToEndOfWord()
  'editor:delete-line': -> @deleteLine()
  'editor:cut-to-end-of-line': -> @cutToEndOfLine()
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
  'editor:select-to-beginning-of-next-paragraph': -> @selectToBeginningOfNextParagraph()
  'editor:select-to-beginning-of-previous-paragraph': -> @selectToBeginningOfPreviousParagraph()
  'editor:select-to-end-of-line': -> @selectToEndOfLine()
  'editor:select-to-beginning-of-line': -> @selectToBeginningOfLine()
  'editor:select-to-end-of-word': -> @selectToEndOfWord()
  'editor:select-to-beginning-of-word': -> @selectToBeginningOfWord()
  'editor:select-to-beginning-of-next-word': -> @selectToBeginningOfNextWord()
  'editor:select-to-next-word-boundary': -> @selectToNextWordBoundary()
  'editor:select-to-previous-word-boundary': -> @selectToPreviousWordBoundary()
  'editor:select-to-first-character-of-line': -> @selectToFirstCharacterOfLine()
  'editor:select-line': -> @selectLinesContainingCursors()
  'editor:transpose': -> @transpose()
  'editor:upper-case': -> @upperCase()
  'editor:lower-case': -> @lowerCase()
)

atom.commands.add 'atom-text-editor:not([mini])', stopEventPropagationAndGroupUndo(
  'core:move-up': -> @moveUp()
  'core:move-down': -> @moveDown()
  'core:move-to-top': -> @moveToTop()
  'core:move-to-bottom': -> @moveToBottom()
  'core:page-up': -> @pageUp()
  'core:page-down': -> @pageDown()
  'core:select-up': -> @selectUp()
  'core:select-down': -> @selectDown()
  'core:select-to-top': -> @selectToTop()
  'core:select-to-bottom': -> @selectToBottom()
  'core:select-page-up': -> @selectPageUp()
  'core:select-page-down': -> @selectPageDown()
  'editor:indent': -> @indent()
  'editor:auto-indent': -> @autoIndentSelectedRows()
  'editor:indent-selected-rows': -> @indentSelectedRows()
  'editor:outdent-selected-rows': -> @outdentSelectedRows()
  'editor:newline': -> @insertNewline()
  'editor:newline-below': -> @insertNewlineBelow()
  'editor:newline-above': -> @insertNewlineAbove()
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
  'editor:toggle-line-comments': -> @toggleLineCommentsInSelection()
  'editor:log-cursor-scope': -> @logCursorScope()
  'editor:checkout-head-revision': -> atom.project.getRepositories()[0]?.checkoutHeadForEditor(this)
  'editor:copy-path': -> @copyPathToClipboard()
  'editor:move-line-up': -> @moveLineUp()
  'editor:move-line-down': -> @moveLineDown()
  'editor:duplicate-lines': -> @duplicateLines()
  'editor:join-lines': -> @joinLines()
  'editor:toggle-indent-guide': -> atom.config.set('editor.showIndentGuide', not atom.config.get('editor.showIndentGuide'))
  'editor:toggle-line-numbers': -> atom.config.set('editor.showLineNumbers', not atom.config.get('editor.showLineNumbers'))
  'editor:scroll-to-cursor': -> @scrollToCursorPosition()
)

module.exports = TextEditorElement = document.registerElement 'atom-text-editor', prototype: TextEditorElement.prototype
