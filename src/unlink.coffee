path = require 'path'

CSON = require 'season'
optimist = require 'optimist'

Command = require './command'
config = require './apm'
fs = require './fs'

module.exports =
class Unlink extends Command
  @commandNames: ['unlink']

  constructor: ->
    @devPackagesPath = path.join(config.getAtomDirectory(), 'dev', 'packages')
    @packagesPath = path.join(config.getAtomDirectory(), 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm unlink [<package_path>]

      Delete the symlink in ~/.atom/packages for the package. The package in the
      current working directory is unlinked if no path is given.

      Run `apm links` to view all the currently linked packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('d', 'dev').boolean('dev').describe('dev', 'Unlink package from ~/.atom/dev/packages')
    options.boolean('hard').describe('hard', 'Unlink package from ~/.atom/packages and ~/.atom/dev/packages')
    options.alias('a', 'all').boolean('all').describe('all', 'Unlink all packages in ~/.atom/packages and ~/.atom/dev/packages')

  getDevPackagePath: (packageName) -> path.join(@devPackagesPath, packageName)

  getPackagePath: (packageName) -> path.join(@packagesPath, packageName)

  unlinkPath: (pathToUnlink) ->
    try
      process.stdout.write "Unlinking #{pathToUnlink} "
      fs.unlinkSync(pathToUnlink) if fs.isSymbolicLinkSync(pathToUnlink)
      @logSuccess()
    catch error
      @logFailure()
      throw error

  unlinkAll: (options, callback) ->
    try
      for child in fs.list(@devPackagesPath)
        packagePath = path.join(@devPackagesPath, child)
        @unlinkPath(packagePath) if fs.isSymbolicLinkSync(packagePath)
      unless options.argv.dev
        for child in fs.list(@packagesPath)
          packagePath = path.join(@packagesPath, child)
          @unlinkPath(packagePath) if fs.isSymbolicLinkSync(packagePath)
      callback()
    catch error
      callback(error)

  unlinkPackage: (options, callback) ->
    linkPath = path.resolve(process.cwd(), options.argv._[0] ? '.')
    try
      packageName = CSON.readFileSync(CSON.resolve(path.join(linkPath, 'package'))).name
    packageName = path.basename(linkPath) unless packageName

    if options.argv.hard
      try
        @unlinkPath(@getDevPackagePath(packageName))
        @unlinkPath(@getPackagePath(packageName))
        callback()
      catch error
        callback(error)
    else
      if options.argv.dev
        targetPath = @getDevPackagePath(packageName)
      else
        targetPath = @getPackagePath(packageName)
      try
        @unlinkPath(targetPath)
        callback()
      catch error
        callback(error)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if options.argv.all
      @unlinkAll(options, callback)
    else
      @unlinkPackage(options, callback)
