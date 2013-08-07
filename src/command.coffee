child_process = require 'child_process'

module.exports =
class Command
  spawn: (command, args, remaining...) ->
    options = remaining.shift() if remaining.length >= 2
    callback = remaining.shift()

    spawned = child_process.spawn(command, args, options)

    errorChunks = []
    spawned.stdout.on 'data', (chunk) ->
    spawned.stderr.on 'data', (chunk) -> errorChunks.push(chunk)
    spawned.on 'error', (error) ->
      callback(error, Buffer.concat(errorChunks).toString())
    spawned.on 'close', (code) ->
      callback(code, Buffer.concat(errorChunks).toString())

  fork: (script, args, remaining...) ->
    args.unshift(script)
    @spawn(process.execPath, args, remaining...)
