Command = require 'command-interpreter/command'

module.exports =
class Address extends Command
  execute: (editor) ->
    editor.getSelection().setBufferRange(@getRange(editor))

  isAddress: -> true
