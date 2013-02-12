{View, $$, $$$} = require 'space-pen'
CommandInterpreter = require './command-interpreter'
RegexAddress = require './commands/regex-address'
CompositeCommand = require './commands/composite-command'
PreviewList = require './preview-list'
Editor = require 'editor'
{SyntaxError} = require('pegjs').parser
_ = require 'underscore'

module.exports =
class CommandPanelView extends View
  @content: ->
    @div class: 'command-panel tool-panel', =>
      @div outlet: 'previewCount', class: 'preview-count'
      @subview 'previewList', new PreviewList(rootView)
      @ul class: 'error-messages', outlet: 'errorMessages'
      @div class: 'prompt-and-editor', =>
        @div class: 'prompt', outlet: 'prompt'
        @subview 'miniEditor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0
  maxSerializedHistorySize: 100

  initialize: (state={}) ->
    @commandInterpreter = new CommandInterpreter(rootView.project)

    @command 'tool-panel:unfocus', => rootView.focus()
    @command 'core:close', => @detach(); false
    @command 'core:confirm', => @execute()
    @command 'core:move-up', => @navigateBackwardInHistory()
    @command 'core:move-down', => @navigateForwardInHistory()

    rootView.command 'command-panel:toggle', => @toggle()
    rootView.command 'command-panel:toggle-preview', => @togglePreview()
    rootView.command 'command-panel:find-in-file', => @attach('/')
    rootView.command 'command-panel:find-in-project', => @attach('Xx/')
    rootView.command 'command-panel:repeat-relative-address', => @repeatRelativeAddress()
    rootView.command 'command-panel:repeat-relative-address-in-reverse', => @repeatRelativeAddressInReverse()
    rootView.command 'command-panel:set-selection-as-regex-address', => @setSelectionAsLastRelativeAddress()

    @previewList.hide()
    @previewCount.hide()
    @errorMessages.hide()
    @prompt.iconSize(@miniEditor.getFontSize())

    @history = state.history ? []
    @historyIndex = @history.length

  serialize: ->
    text: @miniEditor.getText()
    history: @history[-@maxSerializedHistorySize..]

  destroy: ->
    @previewList.destroy()

  toggle: ->
    if @miniEditor.isFocused
      @detach()
      rootView.focus()
    else
      @attach() unless @hasParent()
      @miniEditor.focus()

  togglePreview: ->
    if @previewList.is(':focus')
      @previewList.hide()
      @previewCount.hide()
      @detach()
      rootView.focus()
    else
      @attach() unless @hasParent()
      if @previewList.hasOperations()
        @previewList.show().focus()
        @previewCount.show()
      else
        @miniEditor.focus()

  attach: (text='', options={}) ->
    @errorMessages.hide()

    focus = options.focus ? true
    rootView.vertical.append(this)
    @miniEditor.focus() if focus
    @miniEditor.setText(text)
    @miniEditor.setCursorBufferPosition([0, Infinity])

  detach: ->
    rootView.focus()
    @previewList.hide()
    @previewCount.hide()
    super

  escapedCommand: ->
    @miniEditor.getText()

  execute: (command=@escapedCommand())->
    @errorMessages.empty()

    try
      @commandInterpreter.eval(command, rootView.getActiveEditSession()).done ({operationsToPreview, errorMessages}) =>
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
          @previewCount.text("#{_.pluralize(operationsToPreview.length, 'match', 'matches')} in #{_.pluralize(@previewList.getPathCount(), 'file')}").show()
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
    @commandInterpreter.repeatRelativeAddress(rootView.getActiveEditSession())

  repeatRelativeAddressInReverse: ->
    @commandInterpreter.repeatRelativeAddressInReverse(rootView.getActiveEditSession())

  setSelectionAsLastRelativeAddress: ->
    selection = rootView.getActiveEditor().getSelectedText()
    regex = _.escapeRegExp(selection)
    @commandInterpreter.lastRelativeAddress = new CompositeCommand([new RegexAddress(regex)])
