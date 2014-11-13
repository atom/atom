app = require 'app'
ChildProcess = require 'child_process'
path = require 'path'

updateDotExe = path.resolve(path.dirname(process.execPath), '..', 'Update.exe')
exeName = path.basename(process.execPath)

createShortcut = ->
  ChildProcess.execFile updateDotExe, ['--createShortcut', exeName], ->
    app.quit()

removeShortcut = ->
  ChildProcess.execFile updateDotExe, ['--removeShortcut', exeName], ->
    app.quit()

module.exports = ->
  switch process.argv[1]
    when '--squirrel-install', '--squirrel-updated'
      createShortcut()
      true
    when '--squirrel-uninstall'
      removeShortcut()
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
