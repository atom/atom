{View, $$$} = require 'space-pen'
CommandInterpreter = require 'command-panel/command-interpreter'
RegexAddress = require 'command-panel/commands/regex-address'
CompositeCommand = require 'command-panel/commands/composite-command'
PreviewList = require 'command-panel/preview-list'
Editor = require 'editor'
{SyntaxError} = require('pegjs').parser

_ = require 'underscore'

module.exports =
class CommandPanel extends View
  @activate: (rootView, state) ->
    requireStylesheet 'command-panel.css'
    if state?
      @instance = CommandPanel.deserialize(state, rootView)
    else
      @instance = new CommandPanel(rootView)

  @deactivate: ->
    @instance.destroy()

  @serialize: ->
    text: @instance.miniEditor.getText()
    visible: @instance.hasParent()
    miniEditorFocused: @instance.miniEditor.isFocused
    history: @instance.history[-@instance.maxSerializedHistorySize..]

  @deserialize: (state, rootView) ->
    commandPanel = new CommandPanel(rootView, state.history)
    commandPanel.attach(state.text, focus: false) if state.visible
    commandPanel.miniEditor.focus() if state.miniEditorFocused
    commandPanel

  @content: (rootView) ->
    @div class: 'command-panel', =>
      @subview 'previewList', new PreviewList(rootView)
      @div class: 'prompt-and-editor', =>
        @div ':', class: 'prompt', outlet: 'prompt'
        @subview 'miniEditor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0
  maxSerializedHistorySize: 100

  initialize: (@rootView, @history) ->
    @commandInterpreter = new CommandInterpreter(@rootView.project)

    @history ?= []
    @historyIndex = @history.length

    @on 'command-panel:unfocus', => @rootView.focus()
    @on 'command-panel:close', => @detach()

    @rootView.on 'command-panel:toggle', => @toggle()
    @rootView.on 'command-panel:toggle-preview', => @togglePreview()
    @rootView.on 'command-panel:execute', => @execute()
    @rootView.on 'command-panel:find-in-file', => @attach("/")
    @rootView.on 'command-panel:find-in-project', => @attach("Xx/")
    @rootView.on 'command-panel:repeat-relative-address', => @repeatRelativeAddress()
    @rootView.on 'command-panel:repeat-relative-address-in-reverse', => @repeatRelativeAddressInReverse()
    @rootView.on 'command-panel:set-selection-as-regex-address', => @setSelectionAsLastRelativeAddress()

    @miniEditor.off 'move-up move-down'
    @miniEditor.on 'move-up', => @navigateBackwardInHistory()
    @miniEditor.on 'move-down', => @navigateForwardInHistory()

    @previewList.hide()

  destroy: ->
    @previewList.destroy()

  toggle: ->
    if @miniEditor.isFocused
      @detach()
      @rootView.focus()
    else
      @attach() unless @hasParent()
      @miniEditor.focus()

  togglePreview: ->
    if @previewList.is(':focus')
      @previewList.hide()
      @detach()
      @rootView.focus()
    else
      @attach() unless @hasParent()
      if @previewList.hasOperations()
        @previewList.show().focus()
      else
        @miniEditor.focus()

  attach: (text='', options={}) ->
    focus = options.focus ? true
    @rootView.vertical.append(this)
    @miniEditor.focus() if focus
    @miniEditor.setText(text)
    @miniEditor.setCursorBufferPosition([0, Infinity])

  detach: ->
    @rootView.focus()
    @previewList.hide()
    super

  execute: (command = @miniEditor.getText()) ->
    try
      @commandInterpreter.eval(command, @rootView.getActiveEditSession()).done (operationsToPreview) =>
        @history.push(command)
        @historyIndex = @history.length
        if operationsToPreview?.length
          @previewList.populate(operationsToPreview)
          @previewList.focus()
        else
          @detach()
    catch error
      if error.name is "SyntaxError"
        @flashError()
        return
      else
        throw error

  navigateBackwardInHistory: ->
    return if @historyIndex == 0
    @historyIndex--
    @miniEditor.setText(@history[@historyIndex])

  navigateForwardInHistory: ->
    return if @historyIndex == @history.length
    @historyIndex++
    @miniEditor.setText(@history[@historyIndex] or '')

  repeatRelativeAddress: ->
    @commandInterpreter.repeatRelativeAddress(@rootView.getActiveEditSession())

  repeatRelativeAddressInReverse: ->
    @commandInterpreter.repeatRelativeAddressInReverse(@rootView.getActiveEditSession())

  setSelectionAsLastRelativeAddress: ->
    selection = @rootView.getActiveEditor().getSelectedText()
    regex = _.escapeRegExp(selection)
    @commandInterpreter.lastRelativeAddress = new CompositeCommand([new RegexAddress(regex)])
