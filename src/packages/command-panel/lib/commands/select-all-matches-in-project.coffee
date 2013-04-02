Command = require './command'
Operation = require 'command-panel/lib/operation'
$ = require 'jquery'

module.exports =
class SelectAllMatchesInProject extends Command
  regex: null
  previewOperations: true

  constructor: (pattern) ->
    @regex = new RegExp(pattern)

  compile: (project, buffer, range) ->
    deferred = $.Deferred()
    operations = []
    promise = project.scan @regex, ({path, range, match, lineText}) ->
      operations.push(new Operation(
        project: project
        path: path
        bufferRange: range
        lineText: lineText
      ))

    promise.done -> deferred.resolve(operations)
    deferred.promise()
