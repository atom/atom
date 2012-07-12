_ = require 'underscore'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (editor) ->
    currentRanges = editor.getSelectedBufferRanges()
    for command in @subcommands
      newRanges = []
      for range in currentRanges
        newRanges.push(command.execute(editor, range)...)
      currentRanges = newRanges

    unless command.preserveSelections
      for range in currentRanges
        for row in [range.start.row..range.end.row]
          editor.destroyFoldsContainingBufferRow(row)
      editor.setSelectedBufferRanges(currentRanges)

  reverse: ->
    new CompositeCommand(@subcommands.map (command) -> command.reverse())

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

