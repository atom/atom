$ = require 'jquery'
{View, $$, $$$} = require 'space-pen'
CommandInterpreter = require './command-interpreter'
RegexAddress = require './commands/regex-address'
CompositeCommand = require './commands/composite-command'
PreviewList = require './preview-list'
Editor = require 'editor'
EditSession = require 'edit-session'
{SyntaxError} = require('pegjs').parser
_ = require 'underscore'

module.exports =
class CommandPanelView extends View
  @content: ->
    @div class: 'command-panel tool-panel', =>
      @div class: 'loading is-loading', outlet: 'loadingMessage', =>
        @span 'Searching...'
      @div class: 'header', outlet: 'previewHeader', =>
        @button outlet: 'collapseAll', class: 'btn btn-mini pull-right', 'Collapse All'
        @button outlet: 'expandAll', class: 'btn btn-mini pull-right', 'Expand All'
        @span outlet: 'previewCount', class: 'preview-count'

      @subview 'previewList', new PreviewList(rootView)
      @ul class: 'error-messages', outlet: 'errorMessages'
      @div class: 'search-selections', =>
        @ul class: 'search-options', =>
          @li name: 'regex', class: 'regex', =>
            @div class: 'search-option active', =>
              @span class: 'octicons regexp-icon', outlet: 'searchButton'
          @li name: 'caseSensitive', class: 'case-sensitive', =>
            @div class: 'search-option', =>
              @span class: 'octicons case-sensitive-icon'
          @li name: 'wholeWord', class: 'whole-word', =>
            @div class: 'search-option', =>
              @span class: 'octicons whole-word-icon'
      @div class: 'prompt-and-editor', =>
        @div class: 'prompt', outlet: 'prompt'
        @subview 'miniEditor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0
  maxSerializedHistorySize: 100

  searchOptions = 
    regex: true
    caseSensitive: false
    wholeWord: false

  initialize: (state) ->
    @commandInterpreter = new CommandInterpreter(project)

    @command 'tool-panel:unfocus', => rootView.focus()
    @command 'core:close', => @detach(); false
    @command 'core:cancel', => @detach(); false
    @command 'core:confirm', => @execute()
    @command 'core:move-up', => @navigateBackwardInHistory()
    @command 'core:move-down', => @navigateForwardInHistory()

    @subscribeToCommand rootView, 'command-panel:toggle', => @toggle()
    @subscribeToCommand rootView, 'command-panel:toggle-preview', => @togglePreview()
    @subscribeToCommand rootView, 'command-panel:find-in-file', => @findInFile()
    @subscribeToCommand rootView, 'command-panel:find-in-project', => @findInProject()
    @subscribeToCommand rootView, 'command-panel:repeat-relative-address', => @repeatRelativeAddress()
    @subscribeToCommand rootView, 'command-panel:repeat-relative-address-in-reverse', => @repeatRelativeAddress(reverse: true)
    @subscribeToCommand rootView, 'command-panel:set-selection-as-regex-address', => @setSelectionAsLastRelativeAddress()

    @expandAll.on 'click', @onExpandAll
    @collapseAll.on 'click', @onCollapseAll
    @on 'click', '.search-options', (e) => @searchOptionsClicked(e)

    @previewList.hide()
    @previewHeader.hide()
    @errorMessages.hide()
    @loadingMessage.hide()
    @prompt.iconSize(@miniEditor.getFontSize())

    @history = state.history ? []
    @historyIndex = @history.length

  serialize: ->
    text: @miniEditor.getText()
    history: @history[-@maxSerializedHistorySize..]

  destroy: ->
    @previewList.destroy()
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
    @previewList.expandAllPaths()
    @previewList.focus()

  onCollapseAll: (event) =>
    @previewList.collapseAllPaths()
    @previewList.focus()

  attach: (text, options={}) ->
    @errorMessages.hide()

    focus = options.focus ? true
    rootView.vertical.append(this)
    @miniEditor.focus() if focus
    if text?
      @miniEditor.setText(text)
      @miniEditor.setCursorBufferPosition([0, Infinity])
    else
      @miniEditor.selectAll()

  detach: ->
    rootView.focus()
    @previewList.hide()
    @previewHeader.hide()
    super

  findInFile: ->
    if @miniEditor.getText()[0] is '/'
      @attach()
      @miniEditor.setSelectedBufferRange([[0, 1], [0, Infinity]])
    else
      @attach('/')

  findInProject: ->
    if @miniEditor.getText().indexOf('Xx/') is 0
      @attach()
      @miniEditor.setSelectedBufferRange([[0, 3], [0, Infinity]])
    else
      @attach('Xx/')

  searchOptionsClicked: (event) ->
    toolButton = $(event.target).closest('div')
    if toolButton.hasClass('active')
      toolButton.removeClass('active')
      searchOptions[$(event.target).closest('li').attr('name')] = false
    else
      toolButton.addClass('active')
      searchOptions[$(event.target).closest('li').attr('name')] = true

  escapedCommand: ->
    @miniEditor.getText()

  execute: (command=@escapedCommand()) ->
    @loadingMessage.show()
    @previewList.hide()
    @previewHeader.hide()
    @errorMessages.empty()

    # pass the list of toggled options
    RegexAddress.setOptions searchOptions

    try
      activePaneItem = rootView.getActivePaneItem()
      editSession = activePaneItem if activePaneItem instanceof EditSession
      @commandInterpreter.eval(command, editSession).done ({operationsToPreview, errorMessages}) =>
        @loadingMessage.hide()
        @history.push(command)
        @historyIndex = @history.length

        if errorMessages.length > 0
          @flashError()
          @errorMessages.show()
          @errorMessages.append $$ ->
            @li errorMessage for errorMessage in errorMessages
        else if operationsToPreview?.length
          @previewHeader.show()
          @previewList.populate(operationsToPreview)
          @previewList.focus()
          @previewCount.text("#{_.pluralize(operationsToPreview.length, 'match', 'matches')} in #{_.pluralize(@previewList.getPathCount(), 'file')}").show()
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
