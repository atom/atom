child_process = require 'child_process'

module.exports =
class Command
  spawn: (command, args, remaining...) ->
    options = remaining.shift() if remaining.length >= 2
    callback = remaining.shift()

    spawned = child_process.spawn(command, args, options)
    spawned.stdout.pipe(process.stdout)
    spawned.stderr.pipe(process.stderr)
    spawned.on('error', callback)
    spawned.on('close', callback)
