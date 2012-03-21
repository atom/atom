{View} = require 'space-pen'
CommandInterpreter = require 'command-interpreter'
Editor = require 'editor'

module.exports =
class CommandPanel extends View
  @content: ->
    @div class: 'command-panel', =>
      @div ':', class: 'prompt', outlet: 'prompt'
      @subview 'editor', new Editor

  commandInterpreter: null

  initialize: ({@rootView})->
    requireStylesheet 'command-panel.css'
    window.keymap.bindKeys '.command-panel .editor',
      escape: 'command-panel:toggle'
      enter: 'command-panel:execute'

    @rootView.on 'command-panel:toggle', => @toggle()
    @rootView.on 'command-panel:execute', => @execute()
    @editor.addClass 'single-line'

    @commandInterpreter = new CommandInterpreter()

  toggle: ->
    if @parent().length
      @detach()
      @rootView.activeEditor().focus()
    else
      @rootView.append(this)
      @prompt.css 'font', @editor.css('font')
      @editor.focus()
      @editor.buffer.setText('')

  execute: ->
    @commandInterpreter.eval(@rootView.activeEditor(), @editor.getText())
    @toggle()