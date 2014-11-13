app = require 'app'
path = require 'path'
SquirrelUpdate = require './squirrel-update'

spawnUpdateAndQuit = (option) ->
  exeName = path.basename(process.execPath)
  SquirrelUpdate.spawn ["--#{option}", exeName], -> app.quit()

module.exports = ->
  switch process.argv[1]
    when '--squirrel-install', '--squirrel-updated'
      spawnUpdateAndQuit('createShortcut')
      true
    when '--squirrel-uninstall'
      spawnUpdateAndQuit('removeShortcut')
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
