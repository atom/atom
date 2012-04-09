Command = require 'command-interpreter/command'

module.exports =
class Substitution extends Command
  regex: null
  replacementText: null

  constructor: (pattern, replacementText, options) ->
    @replacementText = replacementText
    @regex = new RegExp(pattern, options.join(''))

  execute: (editor, currentRange) ->
    editor.buffer.scanInRange @regex, currentRange, (match, matchRange, { replace }) =>
      replace(@replacementText)
    [currentRange]
