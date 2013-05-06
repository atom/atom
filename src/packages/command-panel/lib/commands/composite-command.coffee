_ = require 'underscore'
$ = require 'jquery'

module.exports =
class CompositeCommand
  constructor: (@subcommands) ->

  execute: (project, editSession) ->
    currentRanges = editSession?.getSelectedBufferRanges() ? []
    @executeCommands(@subcommands, project, editSession, currentRanges)

  executeCommands: (commands, project, editSession, ranges) ->
    deferred = $.Deferred()
    [currentCommand, remainingCommands...] = commands

    currentCommand.compile(project, editSession?.buffer, ranges).done (operations) =>
      if remainingCommands.length
        errorMessages = @errorMessagesForOperations(operations)
        nextRanges = operations.map (operation) -> operation.getBufferRange()
        operations.forEach (operation) -> operation.destroy()

        @executeCommands(remainingCommands, project, editSession, nextRanges).done ({errorMessages: moreErrorMessages})->
          errorMessages.push(moreErrorMessages...) if moreErrorMessages
          deferred.resolve({errorMessages})
      else
        errorMessages = @errorMessagesForOperations(operations)

        if currentCommand.previewOperations
           deferred.resolve({operationsToPreview: operations, errorMessages})
        else
          bufferRanges = []
          errorMessages = @errorMessagesForOperations(operations)

          executeOperations = ->
            for operation in operations
              bufferRange = operation.execute(editSession)
              bufferRanges.push(bufferRange) if bufferRange
              operation.destroy()

              if bufferRanges.length and not currentCommand.preserveSelections
                editSession.setSelectedBufferRanges(bufferRanges, autoscroll: true)

          operationsWillChangeBuffer = _.detect(operations, (operation) -> operation.newText?)

          if operationsWillChangeBuffer
            editSession.transact(executeOperations)
          else
            executeOperations()

          deferred.resolve({errorMessages})

    deferred.promise()

  errorMessagesForOperations: (operations) ->
    operationsWithErrorMessages = operations.filter (operation) -> operation.errorMessage?
    operationsWithErrorMessages.map (operation) -> operation.errorMessage

  reverse: ->
    new CompositeCommand(@subcommands.map (command) -> command.reverse())

  isRelativeAddress: ->
    _.all(@subcommands, (command) -> command.isAddress() and command.isRelative())
