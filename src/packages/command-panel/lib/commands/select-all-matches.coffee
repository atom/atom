Command = require './command'
Operation = require 'command-panel/lib/operation'
$ = require 'jquery'

module.exports =
class SelectAllMatches extends Command
  regex: null

  constructor: (pattern) ->
    @regex = new RegExp(pattern, 'g')

  compile: (project, buffer, ranges) ->
    deferred = $.Deferred()
    operations = []
    for scanRange in ranges
      buffer.scanInRange @regex, scanRange, ({range}) ->
        operations.push(new Operation(
          project: project
          buffer: buffer
          bufferRange: range
        ))
    deferred.resolve(operations)
    deferred.promise()
