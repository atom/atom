Command = require './command'
Operation = require 'command-panel/lib/operation'
$ = require 'jquery'

module.exports =
class Address extends Command
  compile: (project, buffer, ranges) ->
    deferred = $.Deferred()
    operations = ranges.map (range) =>
      newRange = @getRange(buffer, range)

      new Operation
        project: project
        buffer: buffer
        bufferRange: newRange
        errorMessage: @errorMessage

    deferred.resolve(operations)
    deferred.promise()

  isAddress: -> true
