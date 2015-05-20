path = require 'path'

async = require 'async'
CSON = require 'season'
yargs = require 'yargs'
_ = require 'underscore-plus'

Command = require './command'
config = require './apm'
fs = require './fs'

module.exports =
class Clean extends Command
  @commandNames: ['clean']

  constructor: ->
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  getDependencies: (modulePath, allDependencies) ->
    try
      {dependencies, packageDependencies} = CSON.readFileSync(CSON.resolve(path.join(modulePath, 'package'))) ? {}
    catch error
      return

    _.extend(allDependencies, dependencies)

    modulesPath = path.join(modulePath, 'node_modules')
    for installedModule in fs.list(modulesPath) when installedModule isnt '.bin'
      @getDependencies(path.join(modulesPath, installedModule), allDependencies)

  getModulesToRemove: ->
    packagePath = CSON.resolve('package')
    return [] unless packagePath

    {devDependencies, dependencies, packageDependencies} = CSON.readFileSync(packagePath) ? {}
    devDependencies ?= {}
    dependencies ?= {}
    packageDependencies ?= {}

    modulesToRemove = []
    modulesPath = path.resolve('node_modules')
    installedModules = fs.list(modulesPath).filter (modulePath) ->
      modulePath isnt '.bin' and modulePath isnt 'atom-package-manager'

    # Find all dependencies of all installed modules recursively
    for installedModule in installedModules
      @getDependencies(path.join(modulesPath, installedModule), dependencies)

    # Only remove dependencies that aren't referenced by any installed modules
    for installedModule in installedModules
      continue if dependencies.hasOwnProperty(installedModule)
      continue if devDependencies.hasOwnProperty(installedModule)
      continue if packageDependencies.hasOwnProperty(installedModule)
      modulesToRemove.push(installedModule)

    modulesToRemove

  parseOptions: (argv) ->
    options = yargs(argv).wrap(100)

    options.usage """
      Usage: apm clean

      Deletes all packages in the node_modules folder that are not referenced
      as a dependency in the package.json file.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  removeModule: (module, callback) ->
    process.stdout.write("Removing #{module} ")
    @fork @atomNpmPath, ['uninstall', module], (args...) =>
      @logCommandResults(callback, args...)

  run: (options) ->
    uninstallCommands = []
    @getModulesToRemove().forEach (module) =>
      uninstallCommands.push (callback) => @removeModule(module, callback)

    if uninstallCommands.length > 0
      doneCallback = (error) =>
        if error?
          options.callback(error)
        else
          @run(options)
    else
      doneCallback = options.callback
    async.waterfall(uninstallCommands, doneCallback)
