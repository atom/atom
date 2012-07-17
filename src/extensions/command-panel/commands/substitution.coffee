Command = require 'command-panel/commands/command'
Operation = require 'command-panel/operation'

module.exports =
class Substitution extends Command
  regex: null
  replacementText: null
  preserveSelections: true

  constructor: (pattern, replacementText, options) ->
    @replacementText = replacementText
    @regex = new RegExp(pattern, options.join(''))

  compile: (project, buffer, ranges) ->
    operations = []
    for range in ranges
      buffer.scanInRange @regex, range, (match, matchRange, { replace }) =>
        operations.push(new Operation(
          buffer: buffer,
          bufferRange: matchRange,
          newText: @replacementText
          preserveSelection: true
        ))
    operations
