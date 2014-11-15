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
             apm list --json

      List all the installed packages and also the packages bundled with Atom.
    """
    options.alias('b', 'bare').boolean('bare').describe('bare', 'Print packages one per line with no formatting')
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('i', 'installed').boolean('installed').describe('installed', 'Only list installed packages/themes')
    options.alias('t', 'themes').boolean('themes').describe('themes', 'Only list themes')
    options.alias('j', 'json').boolean('json').describe('json',  'Output all packages as a JSON object')

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

  listUserPackages: (options, callback) ->
    userPackages = @listPackages(@userPackagesDirectory, options)
    unless options.argv.bare or options.argv.json
      console.log "#{@userPackagesDirectory.cyan} (#{userPackages.length})"
    callback(null, userPackages) if callback

  listDevPackages: (options, callback) ->
    devPackages = @listPackages(@devPackagesDirectory, options)
    if devPackages.length > 0
      unless options.argv.bare or options.argv.json
        console.log "#{@devPackagesDirectory.cyan} (#{devPackages.length})"
      callback(null, devPackages) if callback

  listBundledPackages: (options, callback) ->
    config.getResourcePath (resourcePath) =>
      nodeModulesDirectory = path.join(resourcePath, 'node_modules')
      packages = @listPackages(nodeModulesDirectory, options)

      try
        metadataPath = path.join(resourcePath, 'package.json')
        {packageDependencies, _atomPackages} = JSON.parse(fs.readFileSync(metadataPath))
      packageDependencies ?= {}
      _atomPackages ?= {}

      if options.argv.json
        packageMetadata = (v['metadata'] for k, v of _atomPackages)
        packages = packageMetadata.filter ({name}) ->
          packageDependencies.hasOwnProperty(name)
      else
        packages = packages.filter ({name}) ->
          packageDependencies.hasOwnProperty(name)

      unless options.argv.bare or options.argv.json
        if options.argv.themes
          console.log "#{'Built-in Atom themes'.cyan} (#{packages.length})"
        else
          console.log "#{'Built-in Atom packages'.cyan} (#{packages.length})"

      callback(null, packages) if callback

  listInstalledPackages: (options) ->
    @listDevPackages options, (err, packages) =>
      @logPackages(packages, options)
    @listUserPackages options, (err, packages) =>
      @logPackages(packages, options)

  listPackagesAsJson: (options) ->
    out =
      core: []
      dev: []
      user: []

    @listBundledPackages options, (err, packages) =>
      out.core = packages
      @listDevPackages options, (err, packages) =>
        out.dev = packages
        @listUserPackages options, (err, packages) =>
          out.user = packages
          console.log JSON.stringify(out)


  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if options.argv.json
      @listPackagesAsJson(options)
    else if options.argv.installed
      @listInstalledPackages(options)
      callback()
    else
      @listBundledPackages options, (err, packages) =>
        @logPackages(packages, options)
        @listInstalledPackages(options)
        callback()
