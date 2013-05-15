path = require 'path'
fs = require 'fs'
CSON = require 'season'
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
    if configPath = CSON.resolveObjectPath(path.join(config.getAtomDirectory(), 'config'))
      try
        @disabledPackages = CSON.readObjectSync(configPath)?.core?.disabledPackages
    @disabledPackages ?= []

  isDirectory: (directoryPath) ->
    try
      fs.statSync(directoryPath).isDirectory()
    catch e
      false

  isFile: (filePath) ->
    try
      fs.statSync(filePath).isFile()
    catch e
      false

  list: (directoryPath) ->
    if @isDirectory(directoryPath)
      try
        fs.readdirSync(directoryPath)
      catch e
        []
    else
      []

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
    for child in @list(directoryPath)
      manifest = null
      if manifestPath = CSON.resolveObjectPath(path.join(directoryPath, child, 'package'))
        try
          manifest = CSON.readObjectSync(manifestPath) ? {}
          manifest.name ?= child

      unless manifest?
        manifest = name: child if /(\.|_|-)tmbundle$/.test(child)

      packages.push(manifest) if manifest?

    packages

  listUserPackages: ->
    userPackages = @listPackages(@userPackagesDirectory)
    console.log "#{@userPackagesDirectory} (#{userPackages.length})"
    @logPackages(userPackages)

  listBundledPackages: ->
    bundledPackages = @listPackages(@bundledPackagesDirectory)
    console.log "Built-in Atom packages (#{bundledPackages.length})"
    @logPackages(bundledPackages)

  run: (options) ->
    @listUserPackages()
    console.log ''
    @listBundledPackages()
