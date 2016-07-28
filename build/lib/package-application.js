'use strict'

// This is where we'll run electron-packager on our intermediate app dir.
// It takes an ignore regex for paths to exclude, and I've started on a function
// to build up this regexp based on existing work in build-task.coffee. We should
// try to lean on electron-packager to do as much of the work for us as possible
// other than transpilation. It looks like it has a programmatic API. We'll need to
// copy more stuff such as the package.json for the packager to work correctly.

const fs = require('fs-extra')
const path = require('path')
const electronPackager = require('electron-packager')

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
  }, (err, appPaths) => {
    if (err) {
      console.error(err)
    } else {
      if (appPaths.length > 1) {
        throw new Error('TODO: handle this case!')
      }

      if (process.platform === 'darwin') {
        const bundleResourcesPath = path.join(appPaths[0], 'Atom.app', 'Contents', 'Resources')
        fs.copySync(CONFIG.intermediateShellCommandsPath, path.join(bundleResourcesPath, 'app'))
      } else {
        throw new Error('TODO: handle this case!')
      }

      console.log(`Application bundle(s) created on ${appPaths}`)
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
