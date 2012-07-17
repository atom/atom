Command = require 'command-panel/commands/command'
Operation = require 'command-panel/operation'

module.exports =
class SelectAllMatches extends Command
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern, 'g')

  compile: (project, buffer, ranges) ->
    operations = []
    for range in ranges
      buffer.scanInRange @regex, range, (match, matchRange) ->
        operations.push(new Operation(buffer: buffer, bufferRange: matchRange))
    operations
