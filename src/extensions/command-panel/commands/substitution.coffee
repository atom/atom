Command = require 'command-panel/commands/command'

module.exports =
class Substitution extends Command
  regex: null
  replacementText: null
  preserveSelections: true

  constructor: (pattern, replacementText, options) ->
    @replacementText = replacementText
    @regex = new RegExp(pattern, options.join(''))

  execute: (project, buffer, range) ->
    buffer.scanInRange @regex, range, (match, matchRange, { replace }) =>
      replace(@replacementText)
    [range]
