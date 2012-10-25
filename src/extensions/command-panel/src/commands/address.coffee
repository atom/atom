Command = require 'command-panel/src/commands/command'
Operation = require 'command-panel/src/operation'
$ = require 'jquery'

module.exports =
class Address extends Command
  compile: (project, buffer, ranges) ->
    deferred = $.Deferred()
    deferred.resolve ranges.map (range) =>
      new Operation
        project: project
        buffer: buffer
        bufferRange: @getRange(buffer, range)

    deferred.promise()

  isAddress: -> true
