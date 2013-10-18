path = require 'path'

async = require 'async'
CSON = require 'season'
optimist = require 'optimist'
_ = require 'underscore'

Command = require './command'
config = require './config'
fs = require './fs'
Installer = require './installer'

module.exports =
class Cleaner extends Command
  @commandNames: ['clean']

  constructor: ->
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  getDependencies: (modulePath, allDependencies) ->
    try
      {dependencies} = CSON.readFileSync(CSON.resolve(path.join(modulePath, 'package'))) ? {}
    catch error
      return

    _.extend(allDependencies, dependencies)

    modulesPath = path.join(modulePath, 'node_modules')
    for installedModule in fs.list(modulesPath) when installedModule isnt '.bin'
      @getDependencies(path.join(modulesPath, installedModule), allDependencies)

  getModulesToRemove: ->
    {devDependencies, dependencies} = CSON.readFileSync(CSON.resolve('package')) ? {}
    devDependencies ?= {}
    dependencies ?= {}

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
      modulesToRemove.push(installedModule)

    modulesToRemove

  parseOptions: (argv) ->
    options = optimist(argv)

    options.usage """
      Usage: apm clean

      Deletes all packages in the node_modules folder that are not referenced
      as a dependency in the package.json file.
    """
    options.alias('h', 'help').describe('help', 'Print this usage message')

  showHelp: (argv) -> @parseOptions(argv).showHelp()

  run: (options) ->
    uninstallCommands = []
    @getModulesToRemove().forEach (module) =>
      uninstallCommands.push (callback) =>
        process.stdout.write("Removing #{module} ")
        @fork @atomNpmPath, ['uninstall', module], (code, stderr='', stdout='') =>
          if code is 0
            process.stdout.write '\u2713\n'.green
            callback()
          else
            process.stdout.write '\u2717\n'.red
            callback("#{stdout}\n#{stderr}")

    async.waterfall(uninstallCommands, options.callback)
