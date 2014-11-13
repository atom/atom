app = require 'app'
ChildProcess = require 'child_process'
path = require 'path'

spawnUpdateAndQuit = (option) ->
  updateDotExe = path.resolve(path.dirname(process.execPath), '..', 'Update.exe')
  exeName = path.basename(process.execPath)
  updateProcess = ChildProcess.spawn(updateDotExe, ["--#{option}", exeName])
  updateProcess.on 'error', -> # Ignore errors
  updateProcess.on 'close', -> app.quit()
  undefined

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
