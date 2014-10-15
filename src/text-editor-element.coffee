{View, $} = require 'space-pen'
React = require 'react-atom-fork'
{defaults} = require 'underscore-plus'
TextBuffer = require 'text-buffer'
TextEditor = require './text-editor'
TextEditorComponent = require './text-editor-component'
TextEditorView = null

class TextEditorElement extends HTMLElement
  model: null
  componentDescriptor: null
  component: null
  lineOverdrawMargin: null
  focusOnAttach: false

  createdCallback: ->
    @subscriptions =
    @initializeContent()
    @createSpacePenShim()
    @addEventListener 'focus', @focused.bind(this)
    @addEventListener 'focusout', @focusedOut.bind(this)
    @addEventListener 'blur', @blurred.bind(this)

  initializeContent: (attributes) ->
    @classList.add('editor', 'react', 'editor-colors')
    @setAttribute('tabindex', -1)

  createSpacePenShim: ->
    TextEditorView ?= require './text-editor-view'
    @__spacePenView = new TextEditorView(this)

  attachedCallback: ->
    @buildModel() unless @getModel()?
    @mountComponent() unless @component?.isMounted()
    @component.checkForVisibilityChange()
    @focus() if @focusOnAttach

  setModel: (model) ->
    throw new Error("Model already assigned on TextEditorElement") if @model?
    @model = model
    @mountComponent()
    @addGrammarScopeAttribute()
    @model.onDidChangeGrammar => @addGrammarScopeAttribute()
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
      parentView: this
      editor: @model
      mini: @model.mini
      lineOverdrawMargin: @lineOverdrawMargin
    )
    @component = React.renderComponent(@componentDescriptor, this)

  unmountComponent: ->
    return unless @component?.isMounted()
    React.unmountComponentAtNode(this)
    @component = null

  focused: ->
    if @component?
      @component.onFocus()
    else
      @focusOnAttach = true

  focusedOut: (event) ->
    event.stopImmediatePropagation() if @contains(event.relatedTarget)

  blurred: (event) ->
    event.stopImmediatePropagation() if @contains(event.relatedTarget)

  addGrammarScopeAttribute: ->
    grammarScope = @model.getGrammar()?.scopeName?.replace(/\./g, ' ')
    @setAttribute('data-grammar', grammarScope)

  hasFocus: ->
    this is document.activeElement or @contains(document.activeElement)

stopCommandEventPropagation = (commandListeners) ->
  newCommandListeners = {}
  for commandName, commandListener of commandListeners
    do (commandListener) ->
      newCommandListeners[commandName] = (event) ->
        event.stopPropagation()
        commandListener.call(this, event)
  newCommandListeners

atom.commands.add 'atom-text-editor', stopCommandEventPropagation(
  'core:move-left': -> @getModel().moveLeft()
  'core:move-right': -> @getModel().moveRight()
  'core:select-left': -> @getModel().selectLeft()
  'core:select-right': -> @getModel().selectRight()
  'core:select-all': -> @getModel().selectAll()
  'core:backspace': -> @getModel().backspace()
  'core:delete': -> @getModel().delete()
  'core:undo': -> @getModel().undo()
  'core:redo': -> @getModel().redo()
  'core:cut': -> @getModel().cutSelectedText()
  'core:copy': -> @getModel().copySelectedText()
  'core:paste': -> @getModel().pasteText()
  'editor:move-to-previous-word': -> @getModel().moveToPreviousWord()
  'editor:select-word': -> @getModel().selectWordsContainingCursors()
  'editor:consolidate-selections': (event) -> event.abortKeyBinding() unless @getModel().consolidateSelections()
  'editor:delete-to-beginning-of-word': -> @getModel().deleteToBeginningOfWord()
  'editor:delete-to-beginning-of-line': -> @getModel().deleteToBeginningOfLine()
  'editor:delete-to-end-of-line': -> @getModel().deleteToEndOfLine()
  'editor:delete-to-end-of-word': -> @getModel().deleteToEndOfWord()
  'editor:delete-line': -> @getModel().deleteLine()
  'editor:cut-to-end-of-line': -> @getModel().cutToEndOfLine()
  'editor:move-to-beginning-of-next-paragraph': -> @getModel().moveToBeginningOfNextParagraph()
  'editor:move-to-beginning-of-previous-paragraph': -> @getModel().moveToBeginningOfPreviousParagraph()
  'editor:move-to-beginning-of-screen-line': -> @getModel().moveToBeginningOfScreenLine()
  'editor:move-to-beginning-of-line': -> @getModel().moveToBeginningOfLine()
  'editor:move-to-end-of-screen-line': -> @getModel().moveToEndOfScreenLine()
  'editor:move-to-end-of-line': -> @getModel().moveToEndOfLine()
  'editor:move-to-first-character-of-line': -> @getModel().moveToFirstCharacterOfLine()
  'editor:move-to-beginning-of-word': -> @getModel().moveToBeginningOfWord()
  'editor:move-to-end-of-word': -> @getModel().moveToEndOfWord()
  'editor:move-to-beginning-of-next-word': -> @getModel().moveToBeginningOfNextWord()
  'editor:move-to-previous-word-boundary': -> @getModel().moveToPreviousWordBoundary()
  'editor:move-to-next-word-boundary': -> @getModel().moveToNextWordBoundary()
  'editor:select-to-beginning-of-next-paragraph': -> @getModel().selectToBeginningOfNextParagraph()
  'editor:select-to-beginning-of-previous-paragraph': -> @getModel().selectToBeginningOfPreviousParagraph()
  'editor:select-to-end-of-line': -> @getModel().selectToEndOfLine()
  'editor:select-to-beginning-of-line': -> @getModel().selectToBeginningOfLine()
  'editor:select-to-end-of-word': -> @getModel().selectToEndOfWord()
  'editor:select-to-beginning-of-word': -> @getModel().selectToBeginningOfWord()
  'editor:select-to-beginning-of-next-word': -> @getModel().selectToBeginningOfNextWord()
  'editor:select-to-next-word-boundary': -> @getModel().selectToNextWordBoundary()
  'editor:select-to-previous-word-boundary': -> @getModel().selectToPreviousWordBoundary()
  'editor:select-to-first-character-of-line': -> @getModel().selectToFirstCharacterOfLine()
  'editor:select-line': -> @getModel().selectLinesContainingCursors()
  'editor:transpose': -> @getModel().transpose()
  'editor:upper-case': -> @getModel().upperCase()
  'editor:lower-case': -> @getModel().lowerCase()
)

atom.commands.add 'atom-text-editor:not(.mini)', stopCommandEventPropagation(
  'core:move-up': -> @getModel().moveUp()
  'core:move-down': -> @getModel().moveDown()
  'core:move-to-top': -> @getModel().moveToTop()
  'core:move-to-bottom': -> @getModel().moveToBottom()
  'core:page-up': -> @getModel().pageUp()
  'core:page-down': -> @getModel().pageDown()
  'core:select-up': -> @getModel().selectUp()
  'core:select-down': -> @getModel().selectDown()
  'core:select-to-top': -> @getModel().selectToTop()
  'core:select-to-bottom': -> @getModel().selectToBottom()
  'core:select-page-up': -> @getModel().selectPageUp()
  'core:select-page-down': -> @getModel().selectPageDown()
  'editor:indent': -> @getModel().indent()
  'editor:auto-indent': -> @getModel().autoIndentSelectedRows()
  'editor:indent-selected-rows': -> @getModel().indentSelectedRows()
  'editor:outdent-selected-rows': -> @getModel().outdentSelectedRows()
  'editor:newline': -> @getModel().insertNewline()
  'editor:newline-below': -> @getModel().insertNewlineBelow()
  'editor:newline-above': -> @getModel().insertNewlineAbove()
  'editor:add-selection-below': -> @getModel().addSelectionBelow()
  'editor:add-selection-above': -> @getModel().addSelectionAbove()
  'editor:split-selections-into-lines': -> @getModel().splitSelectionsIntoLines()
  'editor:toggle-soft-tabs': -> @getModel().toggleSoftTabs()
  'editor:toggle-soft-wrap': -> @getModel().toggleSoftWrapped()
  'editor:fold-all': -> @getModel().foldAll()
  'editor:unfold-all': -> @getModel().unfoldAll()
  'editor:fold-current-row': -> @getModel().foldCurrentRow()
  'editor:unfold-current-row': -> @getModel().unfoldCurrentRow()
  'editor:fold-selection': -> @getModel().foldSelectedLines()
  'editor:fold-at-indent-level-1': -> @getModel().foldAllAtIndentLevel(0)
  'editor:fold-at-indent-level-2': -> @getModel().foldAllAtIndentLevel(1)
  'editor:fold-at-indent-level-3': -> @getModel().foldAllAtIndentLevel(2)
  'editor:fold-at-indent-level-4': -> @getModel().foldAllAtIndentLevel(3)
  'editor:fold-at-indent-level-5': -> @getModel().foldAllAtIndentLevel(4)
  'editor:fold-at-indent-level-6': -> @getModel().foldAllAtIndentLevel(5)
  'editor:fold-at-indent-level-7': -> @getModel().foldAllAtIndentLevel(6)
  'editor:fold-at-indent-level-8': -> @getModel().foldAllAtIndentLevel(7)
  'editor:fold-at-indent-level-9': -> @getModel().foldAllAtIndentLevel(8)
  'editor:toggle-line-comments': -> @getModel().toggleLineCommentsInSelection()
  'editor:log-cursor-scope': -> @getModel().logCursorScope()
  'editor:checkout-head-revision': -> atom.project.getRepositories()[0]?.checkoutHeadForEditor(@getModel())
  'editor:copy-path': -> @getModel().copyPathToClipboard()
  'editor:move-line-up': -> @getModel().moveLineUp()
  'editor:move-line-down': -> @getModel().moveLineDown()
  'editor:duplicate-lines': -> @getModel().duplicateLines()
  'editor:join-lines': -> @getModel().joinLines()
  'editor:toggle-indent-guide': -> atom.config.set('editor.showIndentGuide', not atom.config.get('editor.showIndentGuide'))
  'editor:toggle-line-numbers': -> atom.config.set('editor.showLineNumbers', not atom.config.get('editor.showLineNumbers'))
  'editor:scroll-to-cursor': -> @getModel().scrollToCursorPosition()
)

module.exports = TextEditorElement = document.registerElement 'atom-text-editor', prototype: TextEditorElement.prototype
