_ = require 'underscore'
$ = require 'jquery'
AllLinesAddress = require 'command-panel/src/commands/all-lines-address'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (project, editSession) ->
    currentRanges = editSession?.getSelectedBufferRanges()

    if not @subcommands[0].isAddress() and currentRanges?.every((range) -> range.isEmpty())
      @subcommands.unshift(new AllLinesAddress())

    @executeCommands(@subcommands, project, editSession, currentRanges)

  executeCommands: (commands, project, editSession, ranges) ->
    deferred = $.Deferred()
    [currentCommand, remainingCommands...] = commands

    currentCommand.compile(project, editSession?.buffer, ranges).done (operations) =>
      if remainingCommands.length
        nextRanges = operations.map (operation) ->
          operation.destroy()
          operation.getBufferRange()
        @executeCommands(remainingCommands, project, editSession, nextRanges).done ->
          deferred.resolve()
      else
        if currentCommand.previewOperations
          deferred.resolve(operations)
        else
          bufferRanges = []
          for operation in operations
            bufferRange = operation.execute(editSession)
            bufferRanges.push(bufferRange) if bufferRange
            operation.destroy()
          if bufferRanges.length and not currentCommand.preserveSelections
            editSession.setSelectedBufferRanges(bufferRanges)
          deferred.resolve()

    deferred.promise()

  reverse: ->
    new CompositeCommand(@subcommands.map (command) -> command.reverse())

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())

