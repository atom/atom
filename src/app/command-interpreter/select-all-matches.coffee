Command = require 'command-interpreter/command'
Range = require 'range'

module.exports =
class SelectAllMatches extends Command
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern, 'g')

  execute: (editor, currentRange) ->
    rangesToSelect = []
    editor.buffer.scanRegexMatchesInRange @regex, currentRange, (match, range) ->
      rangesToSelect.push(range)
    rangesToSelect
