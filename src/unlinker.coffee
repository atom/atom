path = require 'path'

require 'colors'
CSON = require 'season'

fs = require './fs'
config = require './config'

module.exports =
class Unlinker
  constructor: ->
    @devPackagesPath = path.join(config.getAtomDirectory(), 'dev', 'packages')
    @packagesPath = path.join(config.getAtomDirectory(), 'packages')

  getDevPackagePath: (packageName) -> path.join(@devPackagesPath, packageName)

  getPackagePath: (packageName) -> path.join(@packagesPath, packageName)

  unlinkPath: (pathToUnlink) ->
    try
      process.stdout.write "Unlinking #{pathToUnlink} "
      fs.unlinkSync(pathToUnlink) if fs.isLink(pathToUnlink)
      process.stdout.write '\u2713\n'.green
    catch error
      process.stdout.write '\u2713\n'.red
      throw error

  unlinkAll: (options) ->
    try
      for child in fs.list(@devPackagesPath)
        packagePath = path.join(@devPackagesPath, child)
        @unlinkPath(packagePath) if fs.isLink(packagePath)
      unless options.argv.dev
        for child in fs.list(@packagesPath)
          packagePath = path.join(@packagesPath, child)
          @unlinkPath(packagePath) if fs.isLink(packagePath)
      options.callback()
    catch error
      options.callback(error)

  unlinkPackage: (options) ->
    linkPath = path.resolve(process.cwd(), options.commandArgs.shift() ? '.')
    try
      packageName = CSON.readFileSync(CSON.resolve(path.join(linkPath, 'package'))).name
    packageName = path.basename(linkPath) unless packageName

    if options.argv.hard
      try
        @unlinkPath(@getDevPackagePath(packageName))
        @unlinkPath(@getPackagePath(packageName))
        options.callback()
      catch error
        options.callback(error)
    else
      if options.argv.dev
        targetPath = @getDevPackagePath(packageName)
      else
        targetPath = @getPackagePath(packageName)
      try
        @unlinkPath(targetPath)
        options.callback()
      catch error
        options.callback(error)


  run: (options) ->
    if options.argv.all
      @unlinkAll(options)
    else
      @unlinkPackage(options)
