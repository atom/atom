Command = require 'command-interpreter/command'
Range = require 'range'

module.exports =
class SelectAllMatches extends Command
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern, 'g')

  execute: (editor) ->
    rangesToSelect = []
    for selection in editor.getSelections()
      editor.buffer.scanRegexMatchesInRange @regex, selection.getBufferRange(), (match, range) ->
        rangesToSelect.push(range)

    editor.clearSelections()
    editor.setSelectionBufferRange(rangesToSelect[0])
    editor.addSelectionForBufferRange(range) for range in rangesToSelect[1..]
