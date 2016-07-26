path = require 'path'

yargs = require 'yargs'

Command = require './command'
config = require './apm'
fs = require './fs'
tree = require './tree'

module.exports =
class Links extends Command
  @commandNames: ['linked', 'links', 'lns']

  constructor: ->
    @devPackagesPath = path.join(config.getAtomDirectory(), 'dev', 'packages')
    @packagesPath = path.join(config.getAtomDirectory(), 'packages')

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)
    options.usage """

      Usage: apm links

      List all of the symlinked atom packages in ~/.atom/packages and
      ~/.atom/dev/packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  getDevPackagePath: (packageName) -> path.join(@devPackagesPath, packageName)

  getPackagePath: (packageName) -> path.join(@packagesPath, packageName)

  getSymlinks: (directoryPath) ->
    symlinks = []
    for directory in fs.list(directoryPath)
      symlinkPath = path.join(directoryPath, directory)
      symlinks.push(symlinkPath) if fs.isSymbolicLinkSync(symlinkPath)
    symlinks

  logLinks: (directoryPath) ->
    links = @getSymlinks(directoryPath)
    console.log "#{directoryPath.cyan} (#{links.length})"
    tree links, emptyMessage: '(no links)', (link) ->
      try
        realpath = fs.realpathSync(link)
      catch error
        realpath = '???'.red
      "#{path.basename(link).yellow} -> #{realpath}"

  run: (options) ->
    {callback} = options

    @logLinks(@devPackagesPath)
    @logLinks(@packagesPath)
    callback()
