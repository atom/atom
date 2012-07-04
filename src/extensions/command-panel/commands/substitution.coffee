Command = require 'command-panel/commands/command'

module.exports =
class Substitution extends Command
  regex: null
  replacementText: null
  restoreSelections: true

  constructor: (pattern, replacementText, options) ->
    @replacementText = replacementText
    @regex = new RegExp(pattern, options.join(''))

  execute: (editor, currentRange) ->
    editor.scanInRange @regex, currentRange, (match, matchRange, { replace }) =>
      replace(@replacementText)
    [currentRange]
