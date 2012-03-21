{View} = require 'space-pen'
Editor = require 'editor'

module.exports =
class CommandPanel extends View
  @content: ->
    @div class: 'command-panel', =>
      @div ':', class: 'prompt', outlet: 'prompt'
      @subview 'editor', new Editor

  initialize: ({@rootView})->
    requireStylesheet 'command-panel.css'
    window.keymap.bindKeys '.command-panel .editor',
      escape: 'command-panel:toggle'

    @rootView.on 'command-panel:toggle', => @toggle()
    @editor.addClass 'single-line'

  toggle: ->
    if @parent().length
      @detach()
      @rootView.lastActiveEditor().focus()
    else
      @rootView.append(this)
      @prompt.css 'font', @editor.css('font')
      @editor.focus()
      @editor.buffer.setText('')

