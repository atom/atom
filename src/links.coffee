path = require 'path'

optimist = require 'optimist'

config = require './config'
fs = require './fs'
tree = require './tree'

module.exports =
class Links
  @commandNames: ['linked', 'links']

  constructor: ->
    @devPackagesPath = path.join(config.getAtomDirectory(), 'dev', 'packages')
    @packagesPath = path.join(config.getAtomDirectory(), 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm links

      List all of the symlinked atom packages in ~/.atom/packages and
      ~/.atom/dev/packages.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  getDevPackagePath: (packageName) -> path.join(@devPackagesPath, packageName)

  getPackagePath: (packageName) -> path.join(@packagesPath, packageName)

  getSymlinks: (directoryPath) ->
    symlinks = []
    for directory in fs.list(directoryPath)
      symlinkPath = path.join(directoryPath, directory)
      symlinks.push(symlinkPath) if fs.isLink(symlinkPath)
    symlinks

  logLinks: (directoryPath) ->
    links = @getSymlinks(directoryPath)
    console.log "#{directoryPath.cyan} (#{links.length})"
    tree links, emptyMessage: '(no links)', (link) =>
      try
        realpath = fs.realpathSync(link)
      catch error
        realpath = '???'.red
      "#{path.basename(link).yellow} -> #{realpath}"

  run: ->
    @logLinks(@devPackagesPath)
    @logLinks(@packagesPath)
