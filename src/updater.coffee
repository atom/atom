Cleaner = require './cleaner'
Installer = require './installer'

module.exports =
class Updater
  run: (options) ->
    finalCallback = options.callback
    options.callback = (error) ->
      if error?
        finalCallback(error)
      else
        options.callback = finalCallback
        new Installer().installDependencies(options)

    new Cleaner().run(options)
