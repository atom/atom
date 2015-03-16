child_process = require 'child_process'
_ = require 'underscore-plus'

module.exports =
class Command
  spawn: (command, args, remaining...) ->
    options = remaining.shift() if remaining.length >= 2
    callback = remaining.shift()

    spawned = child_process.spawn(command, args, options)

    errorChunks = []
    outputChunks = []

    spawned.stdout.on 'data', (chunk) ->
      if options?.streaming
        process.stdout.write chunk
      else
        outputChunks.push(chunk)

    spawned.stderr.on 'data', (chunk) ->
      if options?.streaming
        process.stderr.write chunk
      else
        errorChunks.push(chunk)

    spawned.on 'error', (error) ->
      callback(error, Buffer.concat(errorChunks).toString(), Buffer.concat(outputChunks).toString())
    spawned.on 'close', (code) ->
      callback(code, Buffer.concat(errorChunks).toString(), Buffer.concat(outputChunks).toString())

  fork: (script, args, remaining...) ->
    args.unshift(script)
    @spawn(process.execPath, args, remaining...)

  packageNamesFromArgv: (argv) ->
    @sanitizePackageNames(argv._)

  sanitizePackageNames: (packageNames=[]) ->
    packageNames = packageNames.map (packageName) -> packageName.trim()
    _.compact(_.uniq(packageNames))

  logSuccess: =>
    if process.platform is 'win32'
      process.stdout.write 'done\n'.green
    else
      process.stdout.write '\u2713\n'.green

  logFailure: =>
    if process.platform is 'win32'
      process.stdout.write 'failed\n'.red
    else
      process.stdout.write '\u2717\n'.red

  logCommandResults: (callback, code, stderr='', stdout='') =>
    if code is 0
      @logSuccess()
      callback()
    else
      @logFailure()
      callback("#{stdout}\n#{stderr}".trim())

  normalizeVersion: (version) ->
    if typeof version is 'string'
      # Remove commit SHA suffix
      version.replace(/-.*$/, '')
    else
      version
