'use strict'

const assert = require('assert')
const fs = require('fs-extra')
const path = require('path')
const electronPackager = require('electron-packager')
const includePathInPackagedApp = require('./include-path-in-packaged-app')

const CONFIG = require('../config')

module.exports = function () {
  console.log(`Running electron-packager on ${CONFIG.intermediateAppPath}`)
  electronPackager({
    'app-version': CONFIG.appMetadata.version,
    'arch': process.arch,
    'asar': {unpack: buildAsarUnpackGlobExpression()},
    'build-version': CONFIG.appMetadata.version,
    'download': {cache: CONFIG.cachePath},
    'dir': CONFIG.intermediateAppPath,
    'out': CONFIG.buildOutputPath,
    'overwrite': true,
    'platform': process.platform,
    'version': CONFIG.appMetadata.electronVersion
  }, (err, packagedAppPaths) => {
    if (err) {
      console.error(err)
    } else {
      assert(packagedAppPaths.length === 1, 'Generated more than one electron application!')
      const packagedAppPath = packagedAppPaths[0]
      if (process.platform === 'darwin') {
        const bundledResourcesPath = path.join(packagedAppPath, 'Atom.app', 'Contents', 'Resources')
        const bundledShellCommandsPath = path.join(bundledResourcesPath, 'app')
        console.log(`Copying shell commands to ${bundledShellCommandsPath}...`);
        fs.copySync(
          path.join(CONFIG.repositoryRootPath, 'apm', 'node_modules', 'atom-package-manager'),
          path.join(bundledShellCommandsPath, 'apm'),
          {filter: includePathInPackagedApp}
        )
        if (process.platform !== 'windows') {
          // Existing symlinks on user systems point to an outdated path, so just symlink it to the real location of the apm binary.
          // TODO: Change command installer to point to appropriate path and remove this fallback after a few releases.
          fs.symlinkSync(path.join('..', '..', 'bin', 'apm'), path.join(bundledShellCommandsPath, 'apm', 'node_modules', '.bin', 'apm'))
          fs.copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), path.join(bundledShellCommandsPath, 'atom.sh'))
        }
      } else {
        throw new Error('TODO: handle this case!')
      }

      console.log(`Application bundle(s) created on ${packagedAppPath}`)
    }
  })
}

function buildAsarUnpackGlobExpression () {
  const unpack = [
    '*.node',
    'ctags-config',
    'ctags-darwin',
    'ctags-linux',
    'ctags-win32.exe',
    path.join('**', 'node_modules', 'spellchecker', '**'),
    path.join('**', 'resources', 'atom.png')
  ]

  return `{${unpack.join(',')}}`
}
