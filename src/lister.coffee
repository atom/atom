path = require 'path'

_ = require 'underscore'
CSON = require 'season'

fs = require './fs'
config = require './config'
tree = require './tree'

module.exports =
class Lister
  @commandNames: ['list', 'ls']

  constructor: ->
    @userPackagesDirectory = path.join(config.getAtomDirectory(), 'packages')
    @bundledPackagesDirectory = path.join(config.getResourcePath(), 'src', 'packages')
    @vendoredPackagesDirectory = path.join(config.getResourcePath(), 'vendor', 'packages')
    if configPath = CSON.resolve(path.join(config.getAtomDirectory(), 'config'))
      try
        @disabledPackages = CSON.readFileSync(configPath)?.core?.disabledPackages
    @disabledPackages ?= []

  isPackageDisabled: (name) ->
    @disabledPackages.indexOf(name) isnt -1

  logPackages: (packages) ->
    tree packages, (pack) =>
      packageLine = pack.name
      packageLine += "@#{pack.version}" if pack.version?
      packageLine += ' (disabled)' if @isPackageDisabled(pack.name)
      packageLine

  listPackages: (directoryPath) ->
    packages = []
    for child in fs.list(directoryPath)
      continue unless fs.isDirectory(path.join(directoryPath, child))

      manifest = null
      if manifestPath = CSON.resolve(path.join(directoryPath, child, 'package'))
        try
          manifest = CSON.readFileSync(manifestPath)
      manifest ?= {}
      manifest.name = child
      packages.push(manifest)

    packages

  listUserPackages: ->
    userPackages = @listPackages(@userPackagesDirectory)
    console.log "#{@userPackagesDirectory.cyan} (#{userPackages.length})"
    @logPackages(userPackages)

  listNodeModulesWithAtomEngine: ->
    nodeModulesDirectory = path.join(config.getResourcePath(), 'node_modules')
    allPackages = @listPackages(nodeModulesDirectory)
    allPackages.filter (manifest) -> manifest.engines?.atom?

  listBundledPackages: ->
    bundledPackages = @listPackages(@bundledPackagesDirectory)
    vendoredPackages = @listPackages(@vendoredPackagesDirectory)
    atomEnginePackages = @listNodeModulesWithAtomEngine()
    packages = _.sortBy(bundledPackages.concat(vendoredPackages).concat(atomEnginePackages), 'name')
    console.log "#{'Built-in Atom packages'.cyan} (#{packages.length})"
    @logPackages(packages)

  run: (options) ->
    @listUserPackages()
    console.log ''
    @listBundledPackages()
