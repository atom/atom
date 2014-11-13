ChildProcess = require 'child_process'
fs = require 'fs'

updateDotExe = path.resolve(path.dirname(process.execPath), '..', 'Update.exe')

module.exports =
  spawn: (args, callback) ->
    stdout = ''
    error = null

    args = args.map (arg) -> "\"#{arg.toString().replace(/"/g, '\\"')}\""
    if /\s/.test(updateDotExe)
      args.unshift("\"#{updateDotExe}\"")
    else
      args.unshift(updateDotExe)

    args = ['/s', '/c', "\"#{cmdArgs.join(' ')}\""]
    command = process.env.comspec or 'cmd.exe'

    updateProcess = ChildProcess.spawn(command, args, windowsVerbatimArguments: true)
    updateProcess.stdout.on 'data', (data) -> stdout += data
    updateProcess.on 'error', (processError) -> error ?= processError
    updateProcess.on 'close', (code, signal) ->
      error ?= new Error("Command failed: #{signal}") if code isnt 0
      error?.code ?= code
      error?.stdout ?= stdout
      callback(error, stdout)

    undefined

  existsSync: ->
    fs.existsSync(updateDotExe)
