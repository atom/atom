_ = require 'underscore'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (project, editSession) ->
    currentRanges = editSession.getSelectedBufferRanges()
    for command in @subcommands
      operations?.forEach (o) -> o.destroy()
      operations = []
      for range in currentRanges
        operations.push(command.compile(project, editSession.buffer, range)...)
      currentRanges = operations.map (o) -> o.getBufferRange()

    editSession.clearAllSelections() unless command.preserveSelections
    for operation in operations
      operation.execute(editSession)
      operation.destroy()

  reverse: ->
    new CompositeCommand(@subcommands.map (command) -> command.reverse())

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

