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
      mini: @getAttribute('mini')
      placeholderText: placeholderText
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

  addGrammarScopeAttribute: ->
    grammarScope = @model.getGrammar()?.scopeName?.replace(/\./g, ' ')
    @setAttribute('data-grammar', grammarScope)

module.exports = TextEditorElement = document.registerElement 'atom-text-editor',
  prototype: TextEditorElement.prototype
  extends: 'div'
