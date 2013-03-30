{View, $$, $$$} = require 'space-pen'
CommandInterpreter = require './command-interpreter'
RegexAddress = require './commands/regex-address'
CompositeCommand = require './commands/composite-command'
PreviewList = require './preview-list'
Editor = require 'editor'
{SyntaxError} = require('pegjs').parser
_ = require 'underscore'
$ = require 'jquery'

module.exports =
class CommandPanelView extends View
  @content: ->
    @div class: 'command-panel tool-panel', =>
      @div class: 'header', outlet: 'previewHeader', =>
        @span outlet: 'searchLoadingMessage', class: 'loading', 'Searching...'
        @ul outlet: 'expandCollapse', class: 'expand-collapse', =>
          @li class: 'collapse', 'Collapse All'
        @span outlet: 'previewCount', class: 'preview-count'

      @subview 'previewList', new PreviewList(rootView)
      @ul class: 'error-messages', outlet: 'errorMessages'
      @div class: 'prompt-and-editor', =>
        @div class: 'prompt', outlet: 'prompt'
        @subview 'miniEditor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0
  maxSerializedHistorySize: 100

  initialize: (state) ->
    @commandInterpreter = new CommandInterpreter(project)

    @command 'tool-panel:unfocus', => rootView.focus()
    @command 'core:close', => @detach(); false
    @command 'core:cancel', => @detach(); false
    @command 'core:confirm', => @execute()
    @command 'core:move-up', => @navigateBackwardInHistory()
    @command 'core:move-down', => @navigateForwardInHistory()

    rootView.command 'command-panel:toggle', => @toggle()
    rootView.command 'command-panel:toggle-preview', => @togglePreview()
    rootView.command 'command-panel:find-in-file', => @attach('/')
    rootView.command 'command-panel:find-in-project', => @attach('Xx/')
    rootView.command 'command-panel:repeat-relative-address', => @repeatRelativeAddress()
    rootView.command 'command-panel:repeat-relative-address-in-reverse', => @repeatRelativeAddress(reverse: true)
    rootView.command 'command-panel:set-selection-as-regex-address', => @setSelectionAsLastRelativeAddress()

    @on 'click', '.expand', @onExpandAll
    @on 'click', '.collapse', @onCollapseAll

    @previewList.hide()
    @previewHeader.hide()
    @errorMessages.hide()
    @searchLoadingMessage.hide()
    @expandCollapse.hide()
    @prompt.iconSize(@miniEditor.getFontSize())

    @history = state.history ? []
    @historyIndex = @history.length

  serialize: ->
    text: @miniEditor.getText()
    history: @history[-@maxSerializedHistorySize..]

  destroy: ->
    @previewList.destroy()
    rootView.off "command-panel:toggle-preview command-panel:find-in-file command-panel:find-in-project \
      command-panel:repeat-relative-address command-panel:repeat-relative-address-in-reverse command-panel:set-selection-as-regex-address"
    @remove()

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
      @previewHeader.hide()
      @detach()
      rootView.focus()
    else
      @attach() unless @hasParent()
      if @previewList.hasOperations()
        @previewList.show().focus()
        @previewHeader.show()
      else
        @miniEditor.focus()

  onExpandAll: (event) =>
    elButton = $(event.currentTarget)
    @previewList.expandAllPaths()   
    elButton.removeClass("expand").addClass("collapse")
    elButton.text("Collapse All")
    @previewList.focus()

  onCollapseAll: (event) =>
    elButton = $(event.currentTarget)
    @previewList.collapseAllPaths()
    elButton.removeClass("collapse").addClass("expand")
    elButton.text("Expand All")
    @previewList.focus()

  attach: (text='', options={}) ->
    @errorMessages.hide()

    focus = options.focus ? true
    rootView.vertical.append(this)
    @miniEditor.focus() if focus
    @miniEditor.setText(text)
    @miniEditor.setCursorBufferPosition([0, Infinity])

  detach: ->
    @miniEditor.setText('')
    rootView.focus()
    @previewList.hide()
    @previewHeader.hide()
    super

  escapedCommand: ->
    @miniEditor.getText()

  execute: (command=@escapedCommand()) ->
    @previewHeader.show()
    @searchLoadingMessage.show()
    @errorMessages.empty()
    project.previewList = @previewList
    
    try
      @commandInterpreter.eval(command, rootView.getActivePaneItem()).done ({operationsToPreview, errorMessages}) =>
        @searchLoadingMessage.hide()
        @expandCollapse.show()
        @history.push(command)
        @historyIndex = @history.length

        if errorMessages.length > 0
          @flashError()
          @errorMessages.show()
          @errorMessages.append $$ ->
            @li errorMessage for errorMessage in errorMessages
        else if operationsToPreview?.length
          @previewList.focus()
          @previewCount.text("#{_.pluralize(operationsToPreview.length, 'match', 'matches')} in #{_.pluralize(@previewList.getPathCount(operationsToPreview), 'file')}").show()
        else
          @detach()
    catch error
      @loadingMessage.hide()
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

  repeatRelativeAddress: (options) ->
    @commandInterpreter.repeatRelativeAddress(rootView.getActivePaneItem(), options)

  setSelectionAsLastRelativeAddress: ->
    selection = rootView.getActiveView().getSelectedText()
    regex = _.escapeRegExp(selection)
    @commandInterpreter.lastRelativeAddress = new CompositeCommand([new RegexAddress(regex)])
