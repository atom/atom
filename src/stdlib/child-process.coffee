# node.js child-process
# http://nodejs.org/docs/v0.6.3/api/child_processes.html

_ = require 'underscore'

module.exports =
  exec: (command, options, callback) ->
    callback = options if _.isFunction options

    # make a task
    task = OSX.NSTask.alloc.init

    # try to use their login shell
    task.setLaunchPath "/bin/bash"

    # set stdin to /dev/null
    task.setStandardInput OSX.NSFileHandle.fileHandleWithNullDevice

    # -l = login shell, -c = command
    args = ["-l", "-c", command]
    task.setArguments args

    # setup stdout and stderr
    task.setStandardOutput stdout = OSX.NSPipe.pipe
    task.setStandardError stderr = OSX.NSPipe.pipe
    stdoutHandle = stdout.fileHandleForReading
    stderrHandle = stderr.fileHandleForReading

    # begin
    task.launch

    # read pipes
    err = @readHandle stderrHandle
    out = @readHandle stdoutHandle

    # check for a dirty exit
    if not task.isRunning
      code = task.terminationStatus
      if code > 0
        error = new Error
        error.code = code

    # call callback
    callback error, out, err

  readHandle: (handle) ->
    OSX.NSString.
    alloc.
    initWithData_encoding(handle.readDataToEndOfFile, OSX.NSUTF8StringEncoding).
    toString()
