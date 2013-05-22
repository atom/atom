path = require 'path'
fs = require './fs'
CSON = require 'season'
_ = require 'underscore'
config = require './config'
tree = require './tree'

module.exports =
class Lister
  userPackagesDirectory: null
  bundledPackagesDirectory: null
  disabledPackages: null

  constructor: ->
    @userPackagesDirectory = path.join(config.getAtomDirectory(), 'packages')
    @bundledPackagesDirectory = path.join(config.getResourcePath(), 'src', 'packages')
    @vendoredPackagesDirectory = path.join(config.getResourcePath(), 'vendor', 'packages')
    if configPath = CSON.resolveObjectPath(path.join(config.getAtomDirectory(), 'config'))
      try
        @disabledPackages = CSON.readObjectSync(configPath)?.core?.disabledPackages
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
      if manifestPath = CSON.resolveObjectPath(path.join(directoryPath, child, 'package'))
        try
          manifest = CSON.readObjectSync(manifestPath) ? {}
          manifest.name ?= child
      manifest ?= {}
      manifest.name = child
      packages.push(manifest)

    packages

  listUserPackages: ->
    userPackages = @listPackages(@userPackagesDirectory)
    console.log "#{@userPackagesDirectory} (#{userPackages.length})"
    @logPackages(userPackages)

  listBundledPackages: ->
    bundledPackages = @listPackages(@bundledPackagesDirectory)
    vendoredPackages = @listPackages(@vendoredPackagesDirectory)
    packages = _.sortBy(bundledPackages.concat(vendoredPackages), 'name')
    console.log "Built-in Atom packages (#{packages.length})"
    @logPackages(packages)

  run: (options) ->
    @listUserPackages()
    console.log ''
    @listBundledPackages()
