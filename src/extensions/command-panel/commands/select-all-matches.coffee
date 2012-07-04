Command = require 'command-panel/commands/command'
Range = require 'range'

module.exports =
class SelectAllMatches extends Command
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern, 'g')

  execute: (editor, currentRange) ->
    rangesToSelect = []
    editor.getBuffer().scanInRange @regex, currentRange, (match, range) ->
      rangesToSelect.push(range)
    rangesToSelect
