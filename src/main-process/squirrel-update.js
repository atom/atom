/** @babel */

import fs from 'fs-plus'
import path from 'path'
import Spawner from './spawner'
import WinShell from './win-shell'
import WinPowerShell from './win-powershell'

const appFolder = path.resolve(process.execPath, '..')
const rootAtomFolder = path.resolve(appFolder, '..')
const binFolder = path.join(rootAtomFolder, 'bin')
const updateDotExe = path.join(rootAtomFolder, 'Update.exe')
const exeName = path.basename(process.execPath)

let setxPath
if (process.env.SystemRoot) {
  const system32Path = path.join(process.env.SystemRoot, 'System32')
  setxPath = path.join(system32Path, 'setx.exe')
} else {
  setxPath = 'setx.exe'
}

// Spawn setx.exe and callback when it completes
function spawnSetx (args, callback) {
  return Spawner.spawn(setxPath, args, callback)
}

// Spawn the Update.exe with the given arguments and invoke the callback when
// the command completes.
function spawnUpdate (args, callback) {
  return Spawner.spawn(updateDotExe, args, callback)
}

// Add atom and apm to the PATH
//
// This is done by adding .cmd shims to the root bin folder in the Atom
// install directory that point to the newly installed versions inside
// the versioned app directories.
function addCommandsToPath (callback) {
  function installCommands (callback) {
    const atomCommandPath = path.join(binFolder, 'atom.cmd')
    const relativeAtomPath = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'atom.cmd'))
    const atomCommand = `@echo off\r\n"%~dp0\\${relativeAtomPath}" %*`

    const atomShCommandPath = path.join(binFolder, 'atom')
    const relativeAtomShPath = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'atom.sh'))
    const atomShCommand = `#!/bin/sh\r\n"$(dirname "$0")/${relativeAtomShPath.replace(/\\/g, '/')}" "$@"\r\necho`

    const apmCommandPath = path.join(binFolder, 'apm.cmd')
    const relativeApmPath = path.relative(binFolder, path.join(process.resourcesPath, 'app', 'apm', 'bin', 'apm.cmd'))
    const apmCommand = `@echo off\r\n"%~dp0\\${relativeApmPath}" %*`

    const apmShCommandPath = path.join(binFolder, 'apm')
    const relativeApmShPath = path.relative(binFolder, path.join(appFolder, 'resources', 'cli', 'apm.sh'))
    const apmShCommand = `#!/bin/sh\r\n"$(dirname "$0")/${relativeApmShPath.replace(/\\/g, '/')}" "$@"`

    return fs.writeFile(atomCommandPath, atomCommand, () => {
      fs.writeFile(atomShCommandPath, atomShCommand, () => {
        fs.writeFile(apmCommandPath, apmCommand, () => {
          fs.writeFile(apmShCommandPath, apmShCommand, () => callback())
        })
      })
    })
  }

  function addBinToPath (pathSegments, callback) {
    pathSegments.push(binFolder)
    const newPathEnv = pathSegments.join(';')
    return spawnSetx(['Path', newPathEnv], callback)
  }

  return installCommands((error) => {
    if (error) return callback(error)

    return WinPowerShell.getPath((error, pathEnv) => {
      if (error) return callback(error)

      const pathSegments = pathEnv.split(/;+/).filter(pathSegment => pathSegment)
      if (pathSegments.indexOf(binFolder) === -1) {
        return addBinToPath(pathSegments, callback)
      } else {
        return callback()
      }
    })
  })
}

// Remove atom and apm from the PATH
function removeCommandsFromPath (callback) {
  WinPowerShell.getPath((error, pathEnv) => {
    if (error) return callback(error)

    const pathSegments = pathEnv.split(/;+/).filter(pathSegment => pathSegment && (pathSegment !== binFolder))
    const newPathEnv = pathSegments.join(';')

    if (pathEnv !== newPathEnv) {
      return spawnSetx(['Path', newPathEnv], callback)
    } else {
      return callback()
    }
  })
}

// Create a desktop and start menu shortcut by using the command line API
// provided by Squirrel's Update.exe
function createShortcuts (callback) {
  spawnUpdate(['--createShortcut', exeName], callback)
}

// Update the desktop and start menu shortcuts by using the command line API
// provided by Squirrel's Update.exe
function updateShortcuts (callback) {
  const homeDirectory = fs.getHomeDirectory()

  if (homeDirectory) {
    const desktopShortcutPath = path.join(homeDirectory, 'Desktop', 'Atom.lnk')
    // Check if the desktop shortcut has been previously deleted and
    // and keep it deleted if it was
    return fs.exists(desktopShortcutPath, (desktopShortcutExists) => {
      createShortcuts(() => {
        if (desktopShortcutExists) {
          return callback()
        } else {
          // Remove the unwanted desktop shortcut that was recreated
          return fs.unlink(desktopShortcutPath, callback)
        }
      })
    })
  } else {
    return createShortcuts(callback)
  }
}

// Remove the desktop and start menu shortcuts by using the command line API
// provided by Squirrel's Update.exe
function removeShortcuts (callback) {
  spawnUpdate(['--removeShortcut', exeName], callback)
}

function updateContextMenus (callback) {
  WinShell.fileContextMenu.update(() => {
    WinShell.folderContextMenu.update(() => {
      WinShell.folderBackgroundContextMenu.update(() => callback())
    })
  })
}

export { spawnUpdate as spawn }

// Is the Update.exe installed with Atom?
export function existsSync () {
  return fs.existsSync(updateDotExe)
}

// Restart Atom using the version pointed to by the atom.cmd shim
export function restartAtom (app) {
  const projectPath = global.atomApplication && global.atomApplication.lastFocusedWindow && global.atomApplication.lastFocusedWindow.projectPath

  let args
  if (projectPath) {
    args = [projectPath]
  }
  app.once('will-quit', () => {
    Spawner.spawn(path.join(binFolder, 'atom.cmd'), args)
  })
  return app.quit()
}

// Handle squirrel events denoted by --squirrel-* command line arguments.
export function handleStartupEvent (app, squirrelCommand) {
  switch (squirrelCommand) {
    case '--squirrel-install':
      createShortcuts(() => {
        addCommandsToPath(() => {
          WinShell.fileHandler.register(() => {
            updateContextMenus(() => app.quit())
          })
        })
      })
      return true
    case '--squirrel-updated':
      updateShortcuts(() => {
        addCommandsToPath(() => {
          WinShell.fileHandler.update(() => {
            updateContextMenus(() => app.quit())
          })
        })
      })
      return true
    case '--squirrel-uninstall':
      removeShortcuts(() => {
        removeCommandsFromPath(() => {
          WinShell.fileHandler.deregister(() => {
            WinShell.fileContextMenu.deregister(() => {
              WinShell.folderContextMenu.deregister(() => {
                WinShell.folderBackgroundContextMenu.deregister(() => app.quit())
              })
            })
          })
        })
      })
      return true
    case '--squirrel-obsolete':
      app.quit()
      return true
    default:
      return false
  }
}
