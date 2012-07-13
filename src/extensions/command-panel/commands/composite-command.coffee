_ = require 'underscore'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (project, activeEditSession) ->
    currentRanges = activeEditSession.getSelectedBufferRanges()

    for command in @subcommands
      newRanges = []
      for range in currentRanges
        newRanges.push(command.execute(project, activeEditSession.buffer, range)...)
      currentRanges = newRanges

    unless command.preserveSelections
      activeEditSession.setSelectedBufferRanges(currentRanges)

  reverse: ->
    new CompositeCommand(@subcommands.map (command) -> command.reverse())

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

