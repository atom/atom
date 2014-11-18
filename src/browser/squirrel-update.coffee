app = require 'app'
ChildProcess = require 'child_process'
fs = require 'fs'
path = require 'path'

updateDotExe = path.resolve(path.dirname(process.execPath), '..', 'Update.exe')
exeName = path.basename(process.execPath)

# Registry keys used for context menu
fileKeyPath = 'HKCU\\Software\\Classes\\*\\shell\\Atom'
directoryKeyPath = 'HKCU\\Software\\Classes\\directory\\shell\\Atom'
backgroundKeyPath = 'HKCU\\Software\\Classes\\directory\\background\\shell\\Atom'
environmentKeyPath = 'HKCU\\Environment'

spawn = (command, args, callback) ->
  spawnedProcess = ChildProcess.spawn('reg.exe', args)

  stdout = ''
  spawnedProcess.stdout.on 'data', (data) -> stdout += data

  error = null
  spawnedProcess.on 'error', (processError) -> error ?= processError
  spawnedProcess.on 'close', (code, signal) ->
    error ?= new Error("Command failed: #{signal ? code}") if code isnt 0
    error?.code ?= code
    error?.stdout ?= stdout
    callback(error, stdout)

# Spawn reg.exe and callback when it completes
spawnReg = (args, callback) ->
  spawn('reg.exe', args, callback)

# Spawn the Update.exe with the given arguments and invoke the callback when
# the command completes.
spawnUpdate = (args, callback) ->
  spawn(updateDotExe, args, callback)

installContextMenu = (callback) ->
  addToRegistry = (args, callback) ->
    args.unshift('add')
    args.push('/f')
    spawnReg(args, callback)

  installMenu = (keyPath, callback) ->
    args = [keyPath, '/ve', '/d', 'Open with Atom']
    addToRegistry args, ->
      args = [keyPath, '/v', 'Icon', '/d', process.execPath]
      addToRegistry args, ->
        args = ["#{keyPath}\\command", '/ve', '/d', process.execPath]
        addToRegistry(args, callback)

  installMenu fileKeyPath, ->
    installMenu directoryKeyPath, ->
      installMenu(backgroundKeyPath, callback)

uninstallContextMenu = (callback) ->
  deleteFromRegistry = (keyPath, callback) ->
    spawnReg(['delete', keyPath, '/f'], callback)

  deleteFromRegistry fileKeyPath, ->
    deleteFromRegistry directoryKeyPath, ->
      deleteFromRegistry(backgroundKeyPath, callback)

updatePath = (callback) ->
  getPath = (callback) ->
    spawnReg ['query', environmentKeyPath, '/v', 'Path'], (error, stdout) ->
      lines = stdout.split('\n')
      segments = lines[lines.length - 1].split('    ')
      pathSegment = segments[3..].join('    ')
      console.log pathSegment

  getPath(callback)

exports.spawn = spawnUpdate

# Is the Update.exe installed with Atom?
exports.existsSync = ->
  fs.existsSync(updateDotExe)

# Handle squirrel events denoted by --squirrel-* command line arguments.
exports.handleStartupEvent = ->
  switch process.argv[1]
    when '--squirrel-install', '--squirrel-updated'
      exports.spawn ['--createShortcut', exeName], ->
        installContextMenu ->
          updatePath ->
            app.quit()
      true
    when '--squirrel-uninstall'
      exports.spawn ['--removeShortcut', exeName], ->
        uninstallContextMenu ->
          app.quit()
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
