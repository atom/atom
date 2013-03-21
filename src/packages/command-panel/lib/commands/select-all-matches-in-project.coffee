Command = require './command'
Operation = require 'command-panel/lib/operation'
$ = require 'jquery'

module.exports =
class SelectAllMatchesInProject extends Command
  regex: null
  previewOperations: true

  constructor: (pattern) ->
    @regex = new RegExp(pattern, 'g')

  compile: (project, buffer, range) ->
    deferred = $.Deferred()
    operations = []
    promise = project.scan @regex, ({path, range}) ->
      operations.push(new Operation(
        project: project
        path: path
        bufferRange: range
      ))

    promise.done -> deferred.resolve(operations)
    deferred.promise()
