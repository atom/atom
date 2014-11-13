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

module.exports = (args) ->
  if args['squirrel-install'] or args['squirrel-updated']
    createShortcut()
    true
  else if args['squirrel-uninstall']
    removeShortcut()
    true
  else if args['squirrel-obsolete']
    app.quit()
    true
  else
    false
