{View} = require 'space-pen'
CommandInterpreter = require 'command-interpreter'
Editor = require 'editor'
{SyntaxError} = require('pegjs').parser

module.exports =
class CommandPanel extends View
  @content: ->
    @div class: 'command-panel', =>
      @div ':', class: 'prompt', outlet: 'prompt'
      @subview 'editor', new Editor(mini: true)

  commandInterpreter: null
  history: null
  historyIndex: 0

  initialize: ({@rootView})->
    requireStylesheet 'command-panel.css'

    @commandInterpreter = new CommandInterpreter()
    @history = []

    @rootView.on 'command-panel:toggle', => @toggle()
    @rootView.on 'command-panel:execute', => @execute()
    @rootView.on 'command-panel:find-in-file', => @show("/")
    @rootView.on 'command-panel:repeat-relative-address', => @repeatRelativeAddress()

    @editor.off 'move-up move-down'
    @editor.on 'move-up', => @navigateBackwardInHistory()
    @editor.on 'move-down', => @navigateForwardInHistory()

  toggle: ->
    if @parent().length then @hide() else @show()

  show: (text='') ->
    @rootView.append(this)
    @prompt.css 'font', @editor.css('font')
    @editor.focus()
    @editor.buffer.setText(text)

  hide: ->
    @detach()
    @rootView.activeEditor().focus()

  execute: (command = @editor.getText()) ->
    try
      @commandInterpreter.eval(@rootView.activeEditor(), command)
    catch error
      if error instanceof SyntaxError
        @flashError()
        return
      else
        throw error

    @history.push(command)
    @historyIndex = @history.length
    @hide()

  navigateBackwardInHistory: ->
    return if @historyIndex == 0
    @historyIndex--
    @editor.setText(@history[@historyIndex])

  navigateForwardInHistory: ->
    return if @historyIndex == @history.length
    @historyIndex++
    @editor.setText(@history[@historyIndex] or '')

  repeatRelativeAddress: ->
    @commandInterpreter.repeatRelativeAddress(@rootView.activeEditor())
