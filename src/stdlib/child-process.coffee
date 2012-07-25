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

    $native.exec command, options, (exitStatus, stdout, stderr) ->
      try
        if exitStatus != 0
          deferred.reject({command, exitStatus, stderr})
        else
          deferred.resolve(stdout, stderr)
      catch e
        console.error "In ChildProccess termination callback: ", e.message
        console.error e.stack

    deferred

  @bufferLines: (callback) ->
    buffered = ""
    (data) ->
      buffered += data
      lastNewlineIndex = buffered.lastIndexOf('\n')
      if lastNewlineIndex >= 0
        callback(buffered.substring(0, lastNewlineIndex + 1))
        buffered = buffered.substring(lastNewlineIndex + 1)
