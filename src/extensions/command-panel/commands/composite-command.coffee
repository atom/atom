_ = require 'underscore'
$ = require 'jquery'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (project, editSession) ->
    currentRanges = editSession.getSelectedBufferRanges()
    @executeCommands(@subcommands, project, editSession, currentRanges)

  executeCommands: (commands, project, editSession, ranges) ->
    deferred = $.Deferred()
    [currentCommand, remainingCommands...] = commands

    currentCommand.compile(project, editSession.buffer, ranges).done (operations) =>
      if remainingCommands.length
        nextRanges = operations.map (operation) ->
          operation.destroy()
          operation.getBufferRange()
        @executeCommands(remainingCommands, project, editSession, nextRanges).done ->
          deferred.resolve()
      else
        editSession.clearAllSelections() unless currentCommand.preserveSelections
        for operation in operations
          operation.execute(editSession)
          operation.destroy()
        deferred.resolve()

    deferred.promise()

  reverse: ->
    new CompositeCommand(@subcommands.map (command) -> command.reverse())

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

