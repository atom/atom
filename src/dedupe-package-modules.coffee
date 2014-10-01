path     = require 'path'
CSON     = require 'season'
optimist = require 'optimist'
Command  = require './command'
config   = require './config'
Dedupe   = require './dedupe'
fs       = require './fs'

module.exports =
class DedupePackageModules extends Command
  @commandNames: ['dedupe-package-modules']

  constructor: ->
    @userPackagesDirectory = path.join(config.getAtomDirectory(), 'packages')

  parseOptions: (argv) ->
    options = optimist(argv)
    options.usage """

      Usage: apm dedupe-package-modules

      Reduce module duplication in packages installed to ~/.atom/packages by
      pulling up common dependencies to ~/.atom/package/node_modules

      This command is experimental.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  getInstalledPackages: ->
    packagePaths = []
    for child in fs.list(@userPackagesDirectory)
      continue if child is 'node_modules'

      packagePath = path.join(@userPackagesDirectory, child)
      continue if fs.isSymbolicLinkSync(packagePath)
      continue unless fs.isDirectorySync(packagePath)
      packagePaths.push(packagePath)

    packagePaths

  # Move Atom packages from ~/.atom/packages to  ~/.atom/packages/node_modules
  movePackagesToNodeModulesFolder: (packagePaths) ->
    nodeModulesPath = path.join(@userPackagesDirectory, 'node_modules')
    fs.mkdirSync(nodeModulesPath) unless fs.isDirectorySync(nodeModulesPath)

    for packagePath in packagePaths
      fs.renameSync(packagePath, path.join(nodeModulesPath, path.basename(packagePath)))

    return

  # Move Atom packages from ~/.atom/packages/node_modules to  ~/.atom/packages
  movePackagesToPackagesFolder: (packagePaths) ->
    for packagePath in packagePaths
      packageName = path.basename(packagePath)
      nodeModulesPath = path.join(@userPackagesDirectory, 'node_modules', packageName)
      if fs.isDirectorySync(nodeModulesPath)
        fs.renameSync(nodeModulesPath, packagePath)

    return

  # Build a package.json with installed Atom packages as dependencies to
  # ~/.atom/packages/package.json
  createPackageJson: (packagePaths) ->
    packageJsonPath = path.join(@userPackagesDirectory, 'package.json')
    metadata =
      name: 'atom-packages'
      version: '1.0.0'
      dependencies: {}
    for packagePath in packagePaths
      packageName = path.basename(packagePath)
      packageVersion = CSON.readFileSync(path.join(packagePath, 'package.json')).version
      metadata.dependencies[packageName] = packageVersion
    fs.writeFileSync(packageJsonPath, JSON.stringify(metadata, null, 2))

  deletePackageJson: ->
    fs.removeSync(path.join(@userPackagesDirectory, 'package.json'))

  getDependencies: (dependencies, modulePath) ->
    metadataPath = path.join(modulePath, 'package.json')
    return unless fs.isFileSync(metadataPath)

    for dependency, version of CSON.readFileSync(metadataPath)?.dependencies
      dependencies[dependency] ?= version

    return

  # Dedupe the module dependencies of the installed Atom packages
  dedupeModules: (moduleNames, callback) ->
    new Dedupe().run
      callback: callback
      commandArgs: moduleNames
      cwd: @userPackagesDirectory

  # Find the module dependencies of all the installed Atom packages.
  getModulesToDedupe: (packagePaths) ->
    dependencies = {}
    @getDependencies(dependencies, packagePath) for packagePath in packagePaths
    Object.keys(dependencies)

  # Remove any package names that are also module names to make sure an Atom
  # package is never deduped as a module.
  removePackageNames: (packagePaths, moduleNames) ->
    for packagePath in packagePaths
      delete moduleNames[path.basename(packagePath)]

  run: (options) ->
    {callback, cwd} = options
    options = @parseOptions(options.commandArgs)

    packagePaths = @getInstalledPackages()
    @createPackageJson(packagePaths)
    modulesToDedupe = @getModulesToDedupe(packagePaths)
    @removePackageNames(packagePaths, modulesToDedupe)

    try
      @movePackagesToNodeModulesFolder(packagePaths)
    catch error
      # Move packages back, something went wrong
      try
        @movePackagesToPackagesFolder(packagePaths)
      return callback(error)

    @dedupeModules modulesToDedupe, (dedupeError) =>
      try
        @movePackagesToPackagesFolder(packagePaths)
        @deletePackageJson()
      catch error
        return callback(error) unless dedupeError?

      callback(dedupeError)
