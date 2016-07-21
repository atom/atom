fs = require 'fs-plus'
path = require 'path'
Spawner = require './spawner'
WinShell = require './win-shell'
WinPowerShell = require './win-powershell'

appFolder = path.resolve(process.execPath, '..')
rootAtomFolder = path.resolve(appFolder, '..')
binFolder = path.join(rootAtomFolder, 'bin')
updateDotExe = path.join(rootAtomFolder, 'Update.exe')
exeName = path.basename(process.execPath)

if process.env.SystemRoot
  system32Path = path.join(process.env.SystemRoot, 'System32')
  setxPath = path.join(system32Path, 'setx.exe')
else
  setxPath = 'setx.exe'

# Spawn setx.exe and callback when it completes
spawnSetx = (args, callback) ->
  Spawner.spawn(setxPath, args, callback)

# Spawn the Update.exe with the given arguments and invoke the callback when
# the command completes.
spawnUpdate = (args, callback) ->
  Spawner.spawn(updateDotExe, args, callback)

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

    WinPowerShell.getPath (error, pathEnv) ->
      return callback(error) if error?

      pathSegments = pathEnv.split(/;+/).filter (pathSegment) -> pathSegment
      if pathSegments.indexOf(binFolder) is -1
        addBinToPath(pathSegments, callback)
      else
        callback()

# Remove atom and apm from the PATH
removeCommandsFromPath = (callback) ->
  WinPowerShell.getPath (error, pathEnv) ->
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
  app.once 'will-quit', -> Spawner.spawn(path.join(binFolder, 'atom.cmd'), args)
  app.quit()

updateContextMenus = (callback) ->
  WinShell.fileContextMenu.update ->
    WinShell.folderContextMenu.update ->
      WinShell.folderBackgroundContextMenu.update ->
        callback()

# Handle squirrel events denoted by --squirrel-* command line arguments.
exports.handleStartupEvent = (app, squirrelCommand) ->
  switch squirrelCommand
    when '--squirrel-install'
      createShortcuts ->
        addCommandsToPath ->
          WinShell.fileHandler.register ->
            updateContextMenus ->
              app.quit()
      true
    when '--squirrel-updated'
      updateShortcuts ->
        addCommandsToPath ->
          updateContextMenus ->
            app.quit()
      true
    when '--squirrel-uninstall'
      removeShortcuts ->
        removeCommandsFromPath ->
          WinShell.fileHandler.deregister ->
            WinShell.fileContextMenu.deregister ->
              WinShell.folderContextMenu.deregister ->
                WinShell.folderBackgroundContextMenu.deregister ->
                  app.quit()
      true
    when '--squirrel-obsolete'
      app.quit()
      true
    else
      false
