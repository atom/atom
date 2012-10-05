EditorCommand = require 'editor-command'

module.exports =
class LowerCaseCommand extends EditorCommand

  @onEditor: (editor) ->
    @register editor, 'meta-Y', 'lowercase', =>
      @replaceSelectedText editor, (text) ->
        text.toLowerCase()
