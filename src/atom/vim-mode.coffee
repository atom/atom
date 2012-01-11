module.exports =
class VimMode
  editor: null

  constructor: (@editor) ->
    atom.bindKeys '.command-mode'
      'i': 'insert-mode:activate'
      'x': 'command-mode:delete'

    atom.bindKeys '.insert-mode'
      '<esc>': 'command-mode:activate'

    @editor.addClass('command-mode')

    @editor.on 'insert-mode:activate', => @activateInsertMode()
    @editor.on 'command-mode:activate', => @activateCommandMode()
    @editor.on 'command-mode:delete', => @delete()

  activateInsertMode: ->
    @editor.removeClass('command-mode')
    @editor.addClass('insert-mode')

  activateCommandMode: ->
    @editor.removeClass('insert-mode')
    @editor.addClass('command-mode')

  delete: ->
    @editor.delete()
