Command = require 'command-interpreter/command'

module.exports =
class Substitution extends Command
  global: false

  constructor: (@findText, @replaceText, @options) ->
    @findRegex = new RegExp(@findText, options.join(''))

  execute: (editor) ->
    editor.buffer.traverseRegexMatchesInRange @findRegex, editor.getSelection().getBufferRange(), =>
      @replaceText

