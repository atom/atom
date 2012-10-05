EditorCommand = require 'editor-command'

module.exports =
class UpperCaseCommand extends EditorCommand

  @onEditor: (editor) ->
    @register editor, 'meta-X', 'uppercase', =>
      @replaceSelectedText editor, (text) ->
        text.toUpperCase()
