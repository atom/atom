let setxPath;
const { app } = require('electron');
const fs = require('fs-plus');
const getAppName = require('../get-app-name');
const path = require('path');
const Spawner = require('./spawner');
const WinShell = require('./win-shell');
const WinPowerShell = require('./win-powershell');

const appFolder = path.resolve(process.execPath, '..');
const rootAtomFolder = path.resolve(appFolder, '..');
const binFolder = path.join(rootAtomFolder, 'bin');
const updateDotExe = path.join(rootAtomFolder, 'Update.exe');
const execName = path.basename(app.getPath('exe'));

if (process.env.SystemRoot) {
  const system32Path = path.join(process.env.SystemRoot, 'System32');
  setxPath = path.join(system32Path, 'setx.exe');
} else {
  setxPath = 'setx.exe';
}

// Spawn setx.exe and callback when it completes
const spawnSetx = (args, callback) => Spawner.spawn(setxPath, args, callback);

// Spawn the Update.exe with the given arguments and invoke the callback when
// the command completes.
const spawnUpdate = (args, callback) =>
  Spawner.spawn(updateDotExe, args, callback);

// Add atom and apm to the PATH
//
// This is done by adding .cmd shims to the root bin folder in the Atom
// install directory that point to the newly installed versions inside
// the versioned app directories.
const addCommandsToPath = callback => {
  const atomCmdName = execName.replace('.exe', '.cmd');
  const apmCmdName = atomCmdName.replace('atom', 'apm');
  const atomShName = execName.replace('.exe', '');
  const apmShName = atomShName.replace('atom', 'apm');

  const installCommands = callback => {
    const atomCommandPath = path.join(binFolder, atomCmdName);
    const relativeAtomPath = path.relative(
      binFolder,
      path.join(appFolder, 'resources', 'cli', 'atom.cmd')
    );
    const atomCommand = `@echo off\r\n"%~dp0\\${relativeAtomPath}" %*`;

    const atomShCommandPath = path.join(binFolder, atomShName);
    const relativeAtomShPath = path.relative(
      binFolder,
      path.join(appFolder, 'resources', 'cli', 'atom.sh')
    );
    const atomShCommand = `#!/bin/sh\r\n"$(dirname "$0")/${relativeAtomShPath.replace(
      /\\/g,
      '/'
    )}" "$@"\r\necho`;

    const apmCommandPath = path.join(binFolder, apmCmdName);
    const relativeApmPath = path.relative(
      binFolder,
      path.join(process.resourcesPath, 'app', 'apm', 'bin', 'apm.cmd')
    );
    const apmCommand = `@echo off\r\n"%~dp0\\${relativeApmPath}" %*`;

    const apmShCommandPath = path.join(binFolder, apmShName);
    const relativeApmShPath = path.relative(
      binFolder,
      path.join(appFolder, 'resources', 'cli', 'apm.sh')
    );
    const apmShCommand = `#!/bin/sh\r\n"$(dirname "$0")/${relativeApmShPath.replace(
      /\\/g,
      '/'
    )}" "$@"`;

    fs.writeFile(atomCommandPath, atomCommand, () =>
      fs.writeFile(atomShCommandPath, atomShCommand, () =>
        fs.writeFile(apmCommandPath, apmCommand, () =>
          fs.writeFile(apmShCommandPath, apmShCommand, () => callback())
        )
      )
    );
  };

  const addBinToPath = (pathSegments, callback) => {
    pathSegments.push(binFolder);
    const newPathEnv = pathSegments.join(';');
    spawnSetx(['Path', newPathEnv], callback);
  };

  installCommands(error => {
    if (error) return callback(error);

    WinPowerShell.getPath((error, pathEnv) => {
      if (error) return callback(error);

      const pathSegments = pathEnv
        .split(/;+/)
        .filter(pathSegment => pathSegment);
      if (pathSegments.indexOf(binFolder) === -1) {
        addBinToPath(pathSegments, callback);
      } else {
        callback();
      }
    });
  });
};

// Remove atom and apm from the PATH
const removeCommandsFromPath = callback =>
  WinPowerShell.getPath((error, pathEnv) => {
    if (error != null) {
      return callback(error);
    }

    const pathSegments = pathEnv
      .split(/;+/)
      .filter(pathSegment => pathSegment && pathSegment !== binFolder);
    const newPathEnv = pathSegments.join(';');

    if (pathEnv !== newPathEnv) {
      return spawnSetx(['Path', newPathEnv], callback);
    } else {
      return callback();
    }
  });

// Create a desktop and start menu shortcut by using the command line API
// provided by Squirrel's Update.exe
const createShortcuts = (locations, callback) =>
  spawnUpdate(
    ['--createShortcut', execName, '-l', locations.join(',')],
    callback
  );

// Update the desktop and start menu shortcuts by using the command line API
// provided by Squirrel's Update.exe
const updateShortcuts = callback => {
  const homeDirectory = fs.getHomeDirectory();
  if (homeDirectory) {
    const desktopShortcutPath = path.join(
      homeDirectory,
      'Desktop',
      `${getAppName()}.lnk`
    );
    // Check if the desktop shortcut has been previously deleted and
    // and keep it deleted if it was
    fs.exists(desktopShortcutPath, desktopShortcutExists => {
      const locations = ['StartMenu'];
      if (desktopShortcutExists) {
        locations.push('Desktop');
      }

      createShortcuts(locations, callback);
    });
  } else {
    createShortcuts(['Desktop', 'StartMenu'], callback);
  }
};

// Remove the desktop and start menu shortcuts by using the command line API
// provided by Squirrel's Update.exe
const removeShortcuts = callback =>
  spawnUpdate(['--removeShortcut', execName], callback);

exports.spawn = spawnUpdate;

// Is the Update.exe installed with Atom?
exports.existsSync = () => fs.existsSync(updateDotExe);

// Restart Atom using the version pointed to by the atom.cmd shim
exports.restartAtom = () => {
  let args;
  const atomCmdName = execName.replace('.exe', '.cmd');

  if (global.atomApplication && global.atomApplication.lastFocusedWindow) {
    const { projectPath } = global.atomApplication.lastFocusedWindow;
    if (projectPath) args = [projectPath];
  }
  Spawner.spawn(path.join(binFolder, atomCmdName), args);
  app.quit();
};

const updateContextMenus = callback =>
  WinShell.fileContextMenu.update(() =>
    WinShell.folderContextMenu.update(() =>
      WinShell.folderBackgroundContextMenu.update(() => callback())
    )
  );

// Handle squirrel events denoted by --squirrel-* command line arguments.
exports.handleStartupEvent = squirrelCommand => {
  switch (squirrelCommand) {
    case '--squirrel-install':
      createShortcuts(['Desktop', 'StartMenu'], () =>
        addCommandsToPath(() =>
          WinShell.fileHandler.register(() =>
            updateContextMenus(() => app.quit())
          )
        )
      );
      return true;
    case '--squirrel-updated':
      updateShortcuts(() =>
        addCommandsToPath(() =>
          WinShell.fileHandler.update(() =>
            updateContextMenus(() => app.quit())
          )
        )
      );
      return true;
    case '--squirrel-uninstall':
      removeShortcuts(() =>
        removeCommandsFromPath(() =>
          WinShell.fileHandler.deregister(() =>
            WinShell.fileContextMenu.deregister(() =>
              WinShell.folderContextMenu.deregister(() =>
                WinShell.folderBackgroundContextMenu.deregister(() =>
                  app.quit()
                )
              )
            )
          )
        )
      );
      return true;
    case '--squirrel-obsolete':
      app.quit();
      return true;
    default:
      return false;
  }
};
