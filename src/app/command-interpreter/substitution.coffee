Command = require 'command-interpreter/command'

module.exports =
class Substitution extends Command
  regex: null
  replacementText: null

  constructor: (pattern, replacementText, options) ->
    @replacementText = replacementText
    @regex = new RegExp(pattern, options.join(''))

  execute: (editor) ->
    range = editor.getSelection().getBufferRange()
    editor.buffer.scanRegexMatchesInRange @regex, range, (match, matchRange, { replace }) =>
      replace(@replacementText)

