ChildProcess = require 'child_process'
fs = require 'fs-plus'
path = require 'path'

appFolder = path.resolve(process.execPath, '..')
rootAtomFolder = path.resolve(appFolder, '..')
binFolder = path.join(rootAtomFolder, 'bin')
updateDotExe = path.join(rootAtomFolder, 'Update.exe')
exeName = path.basename(process.execPath)

if process.env.SystemRoot
  system32Path = path.join(process.env.SystemRoot, 'System32')
  regPath = path.join(system32Path, 'reg.exe')
  powershellPath = path.join(system32Path, 'WindowsPowerShell', 'v1.0', 'powershell.exe')
  setxPath = path.join(system32Path, 'setx.exe')
else
  regPath = 'reg.exe'
  powershellPath = 'powershell.exe'
  setxPath = 'setx.exe'

# Registry keys used for context menu
fileKeyPath = 'HKCU\\Software\\Classes\\*\\shell\\Atom'
directoryKeyPath = 'HKCU\\Software\\Classes\\directory\\shell\\Atom'
backgroundKeyPath = 'HKCU\\Software\\Classes\\directory\\background\\shell\\Atom'
applicationsKeyPath = 'HKCU\\Software\\Classes\\Applications\\atom.exe'
environmentKeyPath = 'HKCU\\Environment'

# Spawn a command and invoke the callback when it completes with an error
# and the output from standard out.
spawn = (command, args, callback) ->
  stdout = ''

  try
    spawnedProcess = ChildProcess.spawn(command, args)
  catch error
    # Spawn can throw an error
    process.nextTick -> callback?(error, stdout)
    return

  spawnedProcess.stdout.on 'data', (data) -> stdout += data

  error = null
  spawnedProcess.on 'error', (processError) -> error ?= processError
  spawnedProcess.on 'close', (code, signal) ->
    error ?= new Error("Command failed: #{signal ? code}") if code isnt 0
    error?.code ?= code
    error?.stdout ?= stdout
    callback?(error, stdout)
  # This is necessary if using Powershell 2 on Windows 7 to get the events to raise
  # http://stackoverflow.com/questions/9155289/calling-powershell-from-nodejs
  spawnedProcess.stdin.end()


# Spawn reg.exe and callback when it completes
spawnReg = (args, callback) ->
  spawn(regPath, args, callback)

# Spawn powershell.exe and callback when it completes
spawnPowershell = (args, callback) ->
  # set encoding and execute the command, capture the output, and return it via .NET's console in order to have consistent UTF-8 encoding
  # http://stackoverflow.com/questions/22349139/utf-8-output-from-powershell
  # to address https://github.com/atom/atom/issues/5063
  args[0] = """
    [Console]::OutputEncoding=[System.Text.Encoding]::UTF8
    $output=#{args[0]}
    [Console]::WriteLine($output)
  """
  args.unshift('-command')
  args.unshift('RemoteSigned')
  args.unshift('-ExecutionPolicy')
  args.unshift('-noprofile')
  spawn(powershellPath, args, callback)

# Spawn setx.exe and callback when it completes
spawnSetx = (args, callback) ->
  spawn(setxPath, args, callback)

# Spawn the Update.exe with the given arguments and invoke the callback when
# the command completes.
spawnUpdate = (args, callback) ->
  spawn(updateDotExe, args, callback)

# Install the Open with Atom explorer context menu items via the registry.
installContextMenu = (callback) ->
  addToRegistry = (args, callback) ->
    args.unshift('add')
    args.push('/f')
    spawnReg(args, callback)

  installFileHandler = (callback) ->
    args = ["#{applicationsKeyPath}\\shell\\open\\command", '/ve', '/d', "\"#{process.execPath}\" \"%1\""]
    addToRegistry(args, callback)

  installMenu = (keyPath, arg, callback) ->
    args = [keyPath, '/ve', '/d', 'Open with Atom']
    addToRegistry args, ->
      args = [keyPath, '/v', 'Icon', '/d', "\"#{process.execPath}\""]
      addToRegistry args, ->
        args = ["#{keyPath}\\command", '/ve', '/d', "\"#{process.execPath}\" \"#{arg}\""]
        addToRegistry(args, callback)

  installMenu fileKeyPath, '%1', ->
    installMenu directoryKeyPath, '%1', ->
      installMenu backgroundKeyPath, '%V', ->
        installFileHandler(callback)

# Get the user's PATH environment variable registry value.
getPath = (callback) ->
  spawnPowershell ['[environment]::GetEnvironmentVariable(\'Path\',\'User\')'], (error, stdout) ->
    if error?
      return callback(error)

    pathOutput = stdout.replace(/^\s+|\s+$/g, '')
    callback(null, pathOutput)

# Uninstall the Open with Atom explorer context menu items via the registry.
uninstallContextMenu = (callback) ->
  deleteFromRegistry = (keyPath, callback) ->
    spawnReg(['delete', keyPath, '/f'], callback)

  deleteFromRegistry fileKeyPath, ->
    deleteFromRegistry directoryKeyPath, ->
      deleteFromRegistry backgroundKeyPath, ->
        deleteFromRegistry(applicationsKeyPath, callback)

# Add atom and apm to the PATH
#
# This is done by adding .cmd shims to the root bin folder in the Atom
# install directory that point to the newly installed versions inside
# the versioned app directories.
addCommandsToPath = (callback) ->
  installCommands = (callback) ->
    atomCommandPath = path.join(binFolder, 'atom.cmd')
    relativeAtomPath = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'atom.cmd'))
    atomCommand = "@echo off\r\n\"%~dp0\\#{relativeAtomPath}\" %*"

    atomShCommandPath = path.join(binFolder, 'atom')
    relativeAtomShPath = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'atom.sh'))
    atomShCommand = "#!/bin/sh\r\n\"$(dirname \"$0\")/#{relativeAtomShPath.replace(/\\/g, '/')}\" \"$@\"\r\necho"

    apmCommandPath = path.join(binFolder, 'apm.cmd')
    relativeApmPath = path.relative(binFolder, path.join(process.resourcesPath, 'app', 'apm', 'bin', 'apm.cmd'))
    apmCommand = "@echo off\r\n\"%~dp0\\#{relativeApmPath}\" %*"

    apmShCommandPath = path.join(binFolder, 'apm')
    relativeApmShPath = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'apm.sh'))
    apmShCommand = "#!/bin/sh\r\n\"$(dirname \"$0\")/#{relativeApmShPath.replace(/\\/g, '/')}\" \"$@\""

    fs.writeFile atomCommandPath, atomCommand, ->
      fs.writeFile atomShCommandPath, atomShCommand, ->
        fs.writeFile apmCommandPath, apmCommand, ->
          fs.writeFile apmShCommandPath, apmShCommand, ->
            callback()

  addBinToPath = (pathSegments, callback) ->
    pathSegments.push(binFolder)
    newPathEnv = pathSegments.join(';')
    spawnSetx(['Path', newPathEnv], callback)

  installCommands (error) ->
    return callback(error) if error?

    getPath (error, pathEnv) ->
      return callback(error) if error?

      pathSegments = pathEnv.split(/;+/).filter (pathSegment) -> pathSegment
      if pathSegments.indexOf(binFolder) is -1
        addBinToPath(pathSegments, callback)
      else
        callback()

# Remove atom and apm from the PATH
removeCommandsFromPath = (callback) ->
  getPath (error, pathEnv) ->
    return callback(error) if error?

    pathSegments = pathEnv.split(/;+/).filter (pathSegment) ->
      pathSegment and pathSegment isnt binFolder
    newPathEnv = pathSegments.join(';')

    if pathEnv isnt newPathEnv
      spawnSetx(['Path', newPathEnv], callback)
    else
      callback()

# Create a desktop and start menu shortcut by using the command line API
# provided by Squirrel's Update.exe
createShortcuts = (callback) ->
  spawnUpdate(['--createShortcut', exeName], callback)

# Update the desktop and start menu shortcuts by using the command line API
# provided by Squirrel's Update.exe
updateShortcuts = (callback) ->
  if homeDirectory = fs.getHomeDirectory()
    desktopShortcutPath = path.join(homeDirectory, 'Desktop', 'Atom.lnk')
    # Check if the desktop shortcut has been previously deleted and
    # and keep it deleted if it was
    fs.exists desktopShortcutPath, (desktopShortcutExists) ->
      createShortcuts ->
        if desktopShortcutExists
          callback()
        else
          # Remove the unwanted desktop shortcut that was recreated
          fs.unlink(desktopShortcutPath, callback)
  else
    createShortcuts(callback)

# Remove the desktop and start menu shortcuts by using the command line API
# provided by Squirrel's Update.exe
removeShortcuts = (callback) ->
  spawnUpdate(['--removeShortcut', exeName], callback)

exports.spawn = spawnUpdate

# Is the Update.exe installed with Atom?
exports.existsSync = ->
  fs.existsSync(updateDotExe)

# Restart Atom using the version pointed to by the atom.cmd shim
exports.restartAtom = (app) ->
  if projectPath = global.atomApplication?.lastFocusedWindow?.projectPath
    args = [projectPath]
  app.once 'will-quit', -> spawn(path.join(binFolder, 'atom.cmd'), args)
  app.quit()

# Handle squirrel events denoted by --squirrel-* command line arguments.
exports.handleStartupEvent = (app, squirrelCommand) ->
  switch squirrelCommand
    when '--squirrel-install'
      createShortcuts ->
        installContextMenu ->
          addCommandsToPath ->
            app.quit()
      true
    when '--squirrel-updated'
      updateShortcuts ->
        installContextMenu ->
          addCommandsToPath ->
            app.quit()
      true
    when '--squirrel-uninstall'
      removeShortcuts ->
        uninstallContextMenu ->
          removeCommandsFromPath ->
            app.quit()
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
