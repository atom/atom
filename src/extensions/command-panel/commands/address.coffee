Command = require 'command-panel/commands/command'

module.exports =
class Address extends Command
  execute: (project, buffer, range) ->
    [@getRange(buffer, range)]

  isAddress: -> true
