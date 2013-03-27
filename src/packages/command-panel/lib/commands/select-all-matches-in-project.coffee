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
    promise = project.scan @regex, ({path, range}) ->
      op = new Operation(
        project: project
        path: path
        bufferRange: range
      )
      project.previewList.populateSingle(op)
      operations.push(op)

    promise.done -> deferred.resolve(operations)
    deferred.promise()
