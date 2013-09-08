path = require 'path'

async = require 'async'
CSON = require 'season'
optimist = require 'optimist'

Command = require './command'
config = require './config'
fs = require './fs'
Installer = require './installer'

module.exports =
class Cleaner extends Command
  @commandNames: ['clean']

  constructor: ->
    @atomNpmPath = require.resolve('npm/bin/npm-cli')

  getModulesToRemove: ->
    {devDependencies, dependencies} = CSON.readFileSync(CSON.resolve('package')) ? {}
    devDependencies ?= {}
    dependencies ?= {}

    modulesToRemove = []
    for installedModule in fs.list('node_modules')
      continue if installedModule is '.bin'
      continue if installedModule is 'atom-package-manager'
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
            callback("#{stdout}\n#{stderr}".red)

    async.waterfall(uninstallCommands, options.callback)
