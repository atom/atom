EditorCommand = require 'editor-command'

module.exports =
class LowerCaseCommand extends EditorCommand

  @getKeymaps: (editor) ->
    'meta-Y': 'lowercase'

  @execute: (editor, event) ->
    @alterSelection editor, (text) ->
      text.toLowerCase()
