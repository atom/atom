Command = require 'command-panel/commands/command'
Range = require 'range'

module.exports =
class SelectAllMatches extends Command
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern, 'g')

  execute: (project, buffer, range) ->
    rangesToSelect = []
    buffer.scanInRange @regex, range, (match, matchRange) ->
      rangesToSelect.push(matchRange)
    rangesToSelect
