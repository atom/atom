# node.js child-process
# http://nodejs.org/docs/v0.6.3/api/child_processes.html

$ = require 'jquery'
_ = require 'underscore'

module.exports =
class ChildProccess
  @exec: (command, options={}) ->
    deferred = $.Deferred()

    if options.bufferLines
      options.stdout = @bufferLines(options.stdout) if options.stdout
      options.stderr = @bufferLines(options.stderr) if options.stderr

    $native.exec command, options, (exitStatus, stdout, stdin) ->
      if error != 0
        error = new Error("Exec failed (#{exitStatus}) command '#{command}'")
        error.exitStatus = exitStatus
        deferred.reject(error)
      else
        deferred.resolve(stdout, stdin)

    deferred

  @bufferLines: (callback) ->
    buffered = ""
    (data) ->
      buffered += data
      lastNewlineIndex = buffered.lastIndexOf('\n')
      if lastNewlineIndex >= 0
        callback(buffered.substring(0, lastNewlineIndex + 1))
        buffered = buffered.substring(lastNewlineIndex + 1)
