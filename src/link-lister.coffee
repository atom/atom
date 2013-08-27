path = require 'path'

require 'colors'

config = require './config'
fs = require './fs'
tree = require './tree'

module.exports =
class LinkLister
  constructor: ->
    @devPackagesPath = path.join(config.getAtomDirectory(), 'dev', 'packages')
    @packagesPath = path.join(config.getAtomDirectory(), 'packages')

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
      "#{path.basename(link).yellow} -> #{fs.realpathSync(link)}"

  run: ->
    @logLinks(@devPackagesPath)
    @logLinks(@packagesPath)
