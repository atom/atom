Command = require 'command-panel/commands/command'

module.exports =
class Address extends Command
  execute: (editor, currentRange) ->
    [@getRange(editor, currentRange)]

  isAddress: -> true
