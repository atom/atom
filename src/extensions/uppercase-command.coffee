EditorCommand = require 'editor-command'

module.exports =
class UpperCaseCommand extends EditorCommand

  @getKeymaps: (editor) ->
    'meta-X': 'uppercase'

  @execute: (editor, event) ->
    @editSelectedText editor, (text) ->
      text.toUpperCase()
