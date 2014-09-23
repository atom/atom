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
             apm list --installed
             apm list --installed --bare > my-packages.txt

      List all the installed packages and also the packages bundled with Atom.
    """
    options.alias('b', 'bare').boolean('bare').describe('bare', 'Print packages one per line with no formatting')
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('i', 'installed').boolean('installed').describe('installed', 'Only list installed packages/themes')
    options.alias('t', 'themes').boolean('themes').describe('themes', 'Only list themes')

  isPackageDisabled: (name) ->
    @disabledPackages.indexOf(name) isnt -1

  logPackages: (packages, options) ->
    if options.argv.bare
      for pack in packages
        packageLine = pack.name
        packageLine += "@#{pack.version}" if pack.version?
        console.log packageLine
    else
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
    unless options.argv.bare
      console.log "#{@userPackagesDirectory.cyan} (#{userPackages.length})"
    @logPackages(userPackages, options)

  listDevPackages: (options) ->
    devPackages = @listPackages(@devPackagesDirectory, options)
    if devPackages.length > 0
      unless options.argv.bare
        console.log "#{@devPackagesDirectory.cyan} (#{devPackages.length})"
      @logPackages(devPackages, options)

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

      unless options.argv.bare
        if options.argv.themes
          console.log "#{'Built-in Atom themes'.cyan} (#{packages.length})"
        else
          console.log "#{'Built-in Atom packages'.cyan} (#{packages.length})"

      @logPackages(packages, options)
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
