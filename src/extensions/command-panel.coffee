{View} = require 'space-pen'
CommandInterpreter = require 'command-interpreter'
RegexAddress = require 'command-interpreter/regex-address'
CompositeCommand = require 'command-interpreter/composite-command'
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

  @serialize: ->
    text: @instance.miniEditor.getText()
    visible: @instance.hasParent()

  @deserialize: (state, rootView) ->
    commandPanel = new CommandPanel(rootView)
    commandPanel.attach(state.text) if state.visible
    commandPanel

  @content: ->
    @div class: 'command-panel', =>
      @div ':', class: 'prompt', outlet: 'prompt'
      @subview 'miniEditor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0

  initialize: (@rootView)->
    @commandInterpreter = new CommandInterpreter()
    @history = []

    @rootView.on 'command-panel:toggle', => @toggle()
    @rootView.on 'command-panel:execute', => @execute()
    @rootView.on 'command-panel:find-in-file', => @attach("/")
    @rootView.on 'command-panel:repeat-relative-address', => @repeatRelativeAddress()
    @rootView.on 'command-panel:repeat-relative-address-in-reverse', => @repeatRelativeAddressInReverse()
    @rootView.on 'command-panel:set-selection-as-regex-address', => @setSelectionAsLastRelativeAddress()

    @miniEditor.off 'move-up move-down'
    @miniEditor.on 'move-up', => @navigateBackwardInHistory()
    @miniEditor.on 'move-down', => @navigateForwardInHistory()

  toggle: ->
    if @parent().length then @detach() else @attach()

  attach: (text='') ->
    @rootView.append(this)
    @miniEditor.focus()
    @miniEditor.buffer.setText(text)
    @prompt.css 'font', @miniEditor.css('font')

  detach: ->
    @rootView.focus()
    super

  execute: (command = @miniEditor.getText()) ->
    try
      @commandInterpreter.eval(@rootView.getActiveEditor(), command)
    catch error
      if error instanceof SyntaxError
        @flashError()
        return
      else
        throw error

    @history.push(command)
    @historyIndex = @history.length
    @detach()

  navigateBackwardInHistory: ->
    return if @historyIndex == 0
    @historyIndex--
    @miniEditor.setText(@history[@historyIndex])

  navigateForwardInHistory: ->
    return if @historyIndex == @history.length
    @historyIndex++
    @miniEditor.setText(@history[@historyIndex] or '')

  repeatRelativeAddress: ->
    @commandInterpreter.repeatRelativeAddress(@rootView.getActiveEditor())

  repeatRelativeAddressInReverse: ->
    @commandInterpreter.repeatRelativeAddressInReverse(@rootView.getActiveEditor())

  setSelectionAsLastRelativeAddress: ->
    selection = @rootView.getActiveEditor().getSelectedText()
    regex = _.escapeRegExp(selection)
    @commandInterpreter.lastRelativeAddress = new CompositeCommand([new RegexAddress(regex)])
