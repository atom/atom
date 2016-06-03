child_process = require 'child_process'
path = require 'path'
_ = require 'underscore-plus'
semver = require 'semver'
config = require './apm'
git = require './git'

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

    onChildExit = (errorOrExitCode) ->
      spawned.removeListener 'error', onChildExit
      spawned.removeListener 'close', onChildExit
      callback?(errorOrExitCode, Buffer.concat(errorChunks).toString(), Buffer.concat(outputChunks).toString())

    spawned.on 'error', onChildExit
    spawned.on 'close', onChildExit

    spawned

  fork: (script, args, remaining...) ->
    args.unshift(script)
    @spawn(process.execPath, args, remaining...)

  packageNamesFromArgv: (argv) ->
    @sanitizePackageNames(argv._)

  sanitizePackageNames: (packageNames=[]) ->
    packageNames = packageNames.map (packageName) -> packageName.trim()
    _.compact(_.uniq(packageNames))

  logSuccess: ->
    if process.platform is 'win32'
      process.stdout.write 'done\n'.green
    else
      process.stdout.write '\u2713\n'.green

  logFailure: ->
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

  logCommandResultsIfFail: (callback, code, stderr='', stdout='') =>
    if code is 0
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

  loadInstalledAtomMetadata: (callback) ->
    @getResourcePath (resourcePath) =>
      try
        {version, electronVersion} = require(path.join(resourcePath, 'package.json')) ? {}
        version = @normalizeVersion(version)
        @installedAtomVersion = version if semver.valid(version)

      # TODO Remove ATOM_NODE_VERSION env var support after a couple releases
      @electronVersion = process.env.ATOM_ELECTRON_VERSION ? process.env.ATOM_NODE_VERSION ? electronVersion ? '0.22.0'

      callback()

  getResourcePath: (callback) ->
    if @resourcePath
      process.nextTick => callback(@resourcePath)
    else
      config.getResourcePath (@resourcePath) => callback(@resourcePath)

  addBuildEnvVars: (env) ->
    @updateWindowsEnv(env) if config.isWin32()
    @addNodeBinToEnv(env)
    @addProxyToEnv(env)

  getVisualStudioFlags: ->
    if vsVersion = config.getInstalledVisualStudioFlag()
      "--msvs_version=#{vsVersion}"

  updateWindowsEnv: (env) ->
    env.USERPROFILE = env.HOME

    # Make sure node-gyp is always on the PATH
    localModuleBins = path.resolve(__dirname, '..', 'node_modules', '.bin')
    if env.Path
      env.Path += "#{path.delimiter}#{localModuleBins}"
    else
      env.Path = localModuleBins

    git.addGitToEnv(env)

  addNodeBinToEnv: (env) ->
    nodeBinFolder = path.resolve(__dirname, '..', 'bin')
    pathKey = if config.isWin32() then 'Path' else 'PATH'
    if env[pathKey]
      env[pathKey] = "#{nodeBinFolder}#{path.delimiter}#{env[pathKey]}"
    else
      env[pathKey]= nodeBinFolder

  addProxyToEnv: (env) ->
    httpProxy = @npm.config.get('proxy')
    if httpProxy
      env.HTTP_PROXY ?= httpProxy
      env.http_proxy ?= httpProxy

    httpsProxy = @npm.config.get('https-proxy')
    if httpsProxy
      env.HTTPS_PROXY ?= httpsProxy
      env.https_proxy ?= httpsProxy
