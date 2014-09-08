path = require 'path'

CSON = require 'season'
optimist = require 'optimist'

Command = require './command'
config = require './config'
fs = require './fs'

module.exports =
class Link extends Command
  @commandNames: ['link', 'ln']

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm link [<package_path>]

      Create a symlink for the package in ~/.atom/packages. The package in the
      current working directory is linked if no path is given.

      Run `apm links` to view all the currently linked packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('d', 'dev').boolean('dev').describe('dev', 'Link to ~/.atom/dev/packages')

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    linkPath = path.resolve(process.cwd(), options.argv._[0] ? '.')
    try
      packageName = CSON.readFileSync(CSON.resolve(path.join(linkPath, 'package'))).name
    packageName = path.basename(linkPath) unless packageName

    if options.argv.dev
      targetPath = path.join(config.getAtomDirectory(), 'dev', 'packages', packageName)
    else
      targetPath = path.join(config.getAtomDirectory(), 'packages', packageName)

    unless fs.existsSync(linkPath)
      callback("Package directory does not exist: #{linkPath}")
      return

    try
      fs.unlinkSync(targetPath) if fs.isSymbolicLinkSync(targetPath)
      fs.makeTreeSync path.dirname(targetPath)
      fs.symlinkSync(linkPath, targetPath, 'junction')
      console.log "#{targetPath} -> #{linkPath}"
      callback()
    catch error
      callback("Linking #{targetPath} to #{linkPath} failed: #{error.message}")
