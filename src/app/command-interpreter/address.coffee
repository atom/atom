Command = require 'command-interpreter/command'

module.exports =
class Address extends Command
  execute: (editor, currentRange) ->
    range = @getRange(editor, currentRange)
    editor.clearSelections()
    editor.setSelectionBufferRange(range)

  isAddress: -> true
