fs = require 'fs'
path = require 'path'

require 'colors'
CSON = require 'season'

config = require './config'

module.exports =
class Unlinker
  constructor: ->

  getDevPackagePath: (packageName) ->
    path.join(config.getAtomDirectory(), 'dev', 'packages', packageName)

  getPackagePath: (packageName) ->
    path.join(config.getAtomDirectory(), 'packages', packageName)

  unlink: (pathToUnlink) ->
    try
      process.stdout.write "Unlinking #{pathToUnlink} "
      fs.unlinkSync(pathToUnlink) if fs.existsSync(pathToUnlink)
      process.stdout.write '\u2713\n'.green
    catch error
      process.stdout.write '\u2713\n'.red
      throw error

  run: (options) ->
    linkPath = path.resolve(process.cwd(), options.commandArgs.shift() ? '.')
    try
      packageName = CSON.readFileSync(CSON.resolve(path.join(linkPath, 'package'))).name
    packageName = path.basename(linkPath) unless packageName

    if options.argv.hard
      try
        @unlink(@getDevPackagePath(packageName))
        @unlink(@getPackagePath(packageName))
        options.callback()
      catch error
        options.callback(error)
    else
      if options.argv.dev
        targetPath = @getDevPackagePath(packageName)
      else
        targetPath = @getPackagePath(packageName)
      try
        @unlink(targetPath)
        options.callback()
      catch error
        options.callback(error)
