Command = require 'command-interpreter/command'

module.exports =
class Address extends Command
  execute: (editor, currentRange) ->
    [@getRange(editor, currentRange)]

  isAddress: -> true
