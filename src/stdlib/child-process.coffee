# node.js child-process
# http://nodejs.org/docs/v0.6.3/api/child_processes.html

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class ChildProccess
  @exec: (command, options={}) ->
    deferred = $.Deferred()
    $native.exec command, options, (exitStatus, stdout, stdin) ->
      if error != 0
        error = new Error("Exec failed (#{exitStatus}) command '#{command}'")
        error.exitStatus = exitStatus
        deferred.reject(error)
      else
        deferred.resolve(stdout, stdin)

    deferred

