{View, $$, $$$} = require 'space-pen'
CommandInterpreter = require 'command-panel/src/command-interpreter'
RegexAddress = require 'command-panel/src/commands/regex-address'
CompositeCommand = require 'command-panel/src/commands/composite-command'
PreviewList = require 'command-panel/src/preview-list'
Editor = require 'editor'
{SyntaxError} = require('pegjs').parser

_ = require 'underscore'

module.exports =
class CommandPanelView extends View
  @activate: (rootView, state) ->
    if state?
      @instance = @deserialize(state, rootView)
    else
      @instance = new CommandPanelView(rootView)

  @deactivate: ->
    @instance.destroy()

  @serialize: ->
    text: @instance.miniEditor.getText()
    visible: @instance.hasParent()
    miniEditorFocused: @instance.miniEditor.isFocused
    history: @instance.history[-@instance.maxSerializedHistorySize..]

  @deserialize: (state, rootView) ->
    commandPanel = new CommandPanelView(rootView, state.history)
    commandPanel.attach(state.text, focus: false) if state.visible
    commandPanel.miniEditor.focus() if state.miniEditorFocused
    commandPanel

  @content: (rootView) ->
    @div class: 'command-panel tool-panel', =>
      @subview 'previewList', new PreviewList(rootView)
      @ul class: 'error-messages', outlet: 'errorMessages'
      @div class: 'prompt-and-editor', =>
        @div class: 'prompt', outlet: 'prompt'
        @subview 'miniEditor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0
  maxSerializedHistorySize: 100

  initialize: (@rootView, @history) ->
    @commandInterpreter = new CommandInterpreter(@rootView.project)

    @history ?= []
    @historyIndex = @history.length

    @command 'tool-panel:unfocus', => @rootView.focus()
    @command 'core:close', => @detach(); false
    @command 'core:confirm', => @execute()

    @rootView.command 'command-panel:toggle', => @toggle()
    @rootView.command 'command-panel:toggle-preview', => @togglePreview()
    @rootView.command 'command-panel:find-in-file', => @attach("/")
    @rootView.command 'command-panel:find-in-project', => @attach("Xx/")
    @rootView.command 'command-panel:repeat-relative-address', => @repeatRelativeAddress()
    @rootView.command 'command-panel:repeat-relative-address-in-reverse', => @repeatRelativeAddressInReverse()
    @rootView.command 'command-panel:set-selection-as-regex-address', => @setSelectionAsLastRelativeAddress()

    @command 'core:move-up', => @navigateBackwardInHistory()
    @command 'core:move-down', => @navigateForwardInHistory()

    @previewList.hide()
    @errorMessages.hide()
    @prompt.iconSize(@miniEditor.fontSize)

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
    console.trace 'attached', @rootView
    @errorMessages.hide()

    focus = options.focus ? true
    @rootView.vertical.append(this)
    @miniEditor.focus() if focus
    @miniEditor.setText(text)
    @miniEditor.setCursorBufferPosition([0, Infinity])

  detach: ->
    @rootView.focus()
    @previewList.hide()
    super

  escapedCommand: ->
    @miniEditor.getText()

  execute: (command=@escapedCommand())->
    @errorMessages.empty()

    try
      @commandInterpreter.eval(command, @rootView.getActiveEditSession()).done ({operationsToPreview, errorMessages}) =>
        @history.push(command)
        @historyIndex = @history.length

        if errorMessages.length > 0
          @flashError()
          @errorMessages.show()
          @errorMessages.append $$ ->
            @li errorMessage for errorMessage in errorMessages
        else if operationsToPreview?.length
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
