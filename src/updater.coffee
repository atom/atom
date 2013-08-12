path = require 'path'

CSON = require 'season'

config = require './config'
fs = require './fs'
Installer = require './installer'

module.exports =
class Updater
  run: (options) ->
    {devDependencies, dependencies} = CSON.readFileSync(CSON.resolve('package')) ? {}
    devDependencies ?= {}
    dependencies ?= {}
    for installedModule in fs.list('node_modules')
      continue if installedModule is '.bin'
      continue if dependencies.hasOwnProperty(installedModule)
      continue if devDependencies.hasOwnProperty(installedModule)

      process.stdout.write("Removing #{installedModule} ")
      try
        fs.rm(path.resolve('node_modules', installedModule))
        process.stdout.write '\u2713\n'.green
      catch e
        process.stdout.write '\u2717\n'.red

    new Installer().installDependencies(options)
