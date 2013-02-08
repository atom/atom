Command = require './command'
Operation = require 'command-panel/lib/operation'
$ = require 'jquery'

module.exports =
class Substitution extends Command
  regex: null
  replacementText: null
  preserveSelections: true

  constructor: (pattern, replacementText, options) ->
    @replacementText = replacementText
    @regex = new RegExp(pattern, options.join(''))

  compile: (project, buffer, ranges) ->
    deferred = $.Deferred()
    operations = []
    for range in ranges
      buffer.scanInRange @regex, range, (match, matchRange) =>
        operations.push(new Operation(
          project: project
          buffer: buffer
          bufferRange: matchRange
          newText: @replacementText
          preserveSelection: true
        ))
    deferred.resolve(operations)
    deferred.promise()
