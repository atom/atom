_ = require 'underscore'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (editor) ->
    for command in @subcommands
      newRanges = []
      currentRanges = editor.getSelectionsOrderedByBufferPosition().map (selection) -> selection.getBufferRange()
      for currentRange in currentRanges
        newRanges.push(command.execute(editor, currentRange)...)
      editor.setSelectedBufferRanges(newRanges, clip: true)

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

