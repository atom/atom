path = require 'path'

_ = require 'underscore-plus'
CSON = require 'season'
optimist = require 'optimist'

Command = require './command'
fs = require './fs'
config = require './apm'
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
             apm list --packages
             apm list --installed
             apm list --installed --bare > my-packages.txt
             apm list --json

      List all the installed packages and also the packages bundled with Atom.
    """
    options.alias('b', 'bare').boolean('bare').describe('bare', 'Print packages one per line with no formatting')
    options.alias('d', 'dev').boolean('dev').default('dev', true).describe('dev', 'Include dev packages')
    options.alias('h', 'help').describe('help', 'Print this usage message')
    options.alias('i', 'installed').boolean('installed').describe('installed', 'Only list installed packages/themes')
    options.alias('j', 'json').boolean('json').describe('json', 'Output all packages as a JSON object')
    options.alias('l', 'links').boolean('links').default('links', true).describe('links', 'Include linked packages')
    options.alias('t', 'themes').boolean('themes').describe('themes', 'Only list themes')
    options.alias('p', 'packages').boolean('packages').describe('packages', 'Only list packages')

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
      unless options.argv.links
        continue if fs.isSymbolicLinkSync(path.join(directoryPath, child))

      manifest = null
      if manifestPath = CSON.resolve(path.join(directoryPath, child, 'package'))
        try
          manifest = CSON.readFileSync(manifestPath)
      manifest ?= {}
      manifest.name = child
      if options.argv.themes
        packages.push(manifest) if manifest.theme
      else if options.argv.packages
        packages.push(manifest) unless manifest.theme
      else
        packages.push(manifest)

    packages

  listUserPackages: (options, callback) ->
    userPackages = @listPackages(@userPackagesDirectory, options)
    unless options.argv.bare or options.argv.json
      console.log "#{@userPackagesDirectory.cyan} (#{userPackages.length})"
    callback?(null, userPackages)

  listDevPackages: (options, callback) ->
    return callback?(null, []) unless options.argv.dev

    devPackages = @listPackages(@devPackagesDirectory, options)
    if devPackages.length > 0
      unless options.argv.bare or options.argv.json
        console.log "#{@devPackagesDirectory.cyan} (#{devPackages.length})"
    callback?(null, devPackages)

  listBundledPackages: (options, callback) ->
    config.getResourcePath (resourcePath) =>
      try
        metadataPath = path.join(resourcePath, 'package.json')
        {_atomPackages} = JSON.parse(fs.readFileSync(metadataPath))
      _atomPackages ?= {}
      packages = (metadata for packageName, {metadata} of _atomPackages)

      packages = packages.filter (metadata) ->
        if options.argv.themes
          metadata.theme
        else if options.argv.packages
          not metadata.theme
        else
          true

      unless options.argv.bare or options.argv.json
        if options.argv.themes
          console.log "#{'Built-in Atom themes'.cyan} (#{packages.length})"
        else
          console.log "#{'Built-in Atom packages'.cyan} (#{packages.length})"

      callback?(null, packages)

  listInstalledPackages: (options) ->
    @listDevPackages options, (error, packages) =>
      @logPackages(packages, options) if packages.length > 0

      @listUserPackages options, (error, packages) =>
        @logPackages(packages, options)

  listPackagesAsJson: (options) ->
    output =
      core: []
      dev: []
      user: []

    @listBundledPackages options, (error, packages) =>
      output.core = packages
      @listDevPackages options, (error, packages) =>
        output.dev = packages
        @listUserPackages options, (error, packages) =>
          output.user = packages
          console.log JSON.stringify(output)

  run: (options) ->
    {callback} = options
    options = @parseOptions(options.commandArgs)

    if options.argv.json
      @listPackagesAsJson(options)
    else if options.argv.installed
      @listInstalledPackages(options)
      callback()
    else
      @listBundledPackages options, (error, packages) =>
        @logPackages(packages, options)
        @listInstalledPackages(options)
        callback()
