Command = require 'command-interpreter/command'

module.exports =
class Address extends Command
  execute: (editor) ->
    range = @getRange(editor)
    editor.clearSelections()
    editor.setSelectionBufferRange(range)

  isAddress: -> true
