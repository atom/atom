_ = require 'underscore'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (editor) ->
    initialRanges = editor.getSelectedBufferRanges()
    for command in @subcommands
      newRanges = []
      currentRanges = editor.getSelectedBufferRanges()
      for currentRange in currentRanges
        newRanges.push(command.execute(editor, currentRange)...)

      for range in newRanges
        for row in [range.start.row..range.end.row]
          editor.destroyFoldsContainingBufferRow(row)

      editor.setSelectedBufferRanges(newRanges)
    editor.setSelectedBufferRanges(initialRanges) if command.restoreSelections

  reverse: ->
    new CompositeCommand(@subcommands.map (command) -> command.reverse())

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

