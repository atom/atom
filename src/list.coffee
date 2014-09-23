path = require 'path'

_ = require 'underscore-plus'
CSON = require 'season'
optimist = require 'optimist'

Command = require './command'
fs = require './fs'
config = require './config'
tree = require './tree'

module.exports =
class List extends Command
  @commandNames: ['list', 'ls']

  constructor: ->
    @userPackagesDirectory = path.join(config.getAtomDirectory(), 'packages')
    @devPackagesDirectory = path.join(config.getAtomDirectory(), 'dev', 'packages')
    if configPath = CSON.resolve(path.join(config.getAtomDirectory(), 'config'))
      try
        @disabledPackages = CSON.readFileSync(configPath)?.core?.disabledPackages
    @disabledPackages ?= []

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm list
             apm list --themes

      List all the installed packages and also the packages bundled with Atom.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('t', 'themes').boolean('themes').describe('themes', 'Only list themes')
    options.alias('i', 'installed').boolean('installed').describe('installed', 'Only list installed packages/themes')

  isPackageDisabled: (name) ->
    @disabledPackages.indexOf(name) isnt -1

  logPackages: (packages) ->
    tree packages, (pack) =>
      packageLine = pack.name
      packageLine += "@#{pack.version}" if pack.version?
      packageLine += ' (disabled)' if @isPackageDisabled(pack.name)
      packageLine
    console.log()

  listPackages: (directoryPath, options) ->
    packages = []
    for child in fs.list(directoryPath)
      continue unless fs.isDirectorySync(path.join(directoryPath, child))

      manifest = null
      if manifestPath = CSON.resolve(path.join(directoryPath, child, 'package'))
        try
          manifest = CSON.readFileSync(manifestPath)
      manifest ?= {}
      manifest.name = child
      if options.argv.themes
        packages.push(manifest) if manifest.theme
      else
        packages.push(manifest)

    packages

  listUserPackages: (options) ->
    userPackages = @listPackages(@userPackagesDirectory, options)
    console.log "#{@userPackagesDirectory.cyan} (#{userPackages.length})"
    @logPackages(userPackages)

  listDevPackages: (options) ->
    devPackages = @listPackages(@devPackagesDirectory, options)
    if devPackages.length > 0
      console.log "#{@devPackagesDirectory.cyan} (#{devPackages.length})"
      @logPackages(devPackages)

  listBundledPackages: (options, callback) ->
    config.getResourcePath (resourcePath) =>
      nodeModulesDirectory = path.join(resourcePath, 'node_modules')
      packages = @listPackages(nodeModulesDirectory, options)

      try
        metadataPath = path.join(resourcePath, 'package.json')
        {packageDependencies} = JSON.parse(fs.readFileSync(metadataPath)) ? {}
      packageDependencies ?= {}

      packages = packages.filter ({name}) ->
        packageDependencies.hasOwnProperty(name)

      if options.argv.themes
        console.log "#{'Built-in Atom themes'.cyan} (#{packages.length})"
      else
        console.log "#{'Built-in Atom packages'.cyan} (#{packages.length})"
      @logPackages(packages)
      callback()

  listInstalledPackages: (options) ->
    @listDevPackages(options)
    @listUserPackages(options)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if options.argv.installed
      @listInstalledPackages(options)
      callback()
    else
      @listBundledPackages options, =>
        @listInstalledPackages(options)
        callback()
