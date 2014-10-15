path = require 'path'
async = require 'async'
Command = require './command'
config = require './config'
fs = require './fs'

module.exports =
class RebuildModuleCache extends Command
  @commandNames: ['rebuild-module-cache']

  constructor: ->
    @atomPackagesDirectory = path.join(config.getAtomDirectory(), 'packages')

  getResourcePath: (callback) ->
    if @resourcePath
      process.nextTick => callback(@resourcePath)
    else
      config.getResourcePath (@resourcePath) => callback(@resourcePath)

  rebuild: (packageDirectory, callback) ->
    @getResourcePath (resourcePath) =>
      try
        @moduleCache ?= require(path.join(resourcePath, 'src', 'module-cache'))
        @moduleCache.create(packageDirectory)
      catch error
        callback(error)

  run: (options) ->
    {callback} = options

    commands = []
    for packageName in fs.list(@atomPackagesDirectory)
      packageDirectory = path.join(@atomPackagesDirectory, packageName)
      continue if fs.isSymbolicLinkSync(packageDirectory)
      continue unless fs.isDirectorySync(packageDirectory)

      commands.push (callback) =>
        process.stdout.write "Rebuilding #{packageName} module cache "
        @rebuild packageDirectory, (error) =>
          if error?
            @logFailure()
          else
            @logSuccess()
          callback(error)

    async.waterfall(commands, callback)
