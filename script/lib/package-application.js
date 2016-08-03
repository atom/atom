'use strict'

const assert = require('assert')
const fs = require('fs-extra')
const path = require('path')
const childProcess = require('child_process')
const electronPackager = require('electron-packager')
const includePathInPackagedApp = require('./include-path-in-packaged-app')
const getLicenseText = require('./get-license-text')

const CONFIG = require('../config')

module.exports = function () {
  const appName = CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'

  console.log(`Running electron-packager on ${CONFIG.intermediateAppPath} with app name "${appName}"`)
  return runPackager({
    'app-version': CONFIG.appMetadata.version,
    'arch': process.arch,
    'asar': {unpack: buildAsarUnpackGlobExpression()},
    'build-version': CONFIG.appMetadata.version,
    'download': {cache: CONFIG.cachePath},
    'dir': CONFIG.intermediateAppPath,
    'icon': getIcon(),
    'name': appName,
    'out': CONFIG.buildOutputPath,
    'osx-sign': getSignOptions(),
    'overwrite': true,
    'platform': process.platform,
    'version': CONFIG.appMetadata.electronVersion
  }).then((packageOutputDirPath) => {
    let packagedAppPath, bundledResourcesPath
    if (process.platform === 'darwin') {
      packagedAppPath = path.join(packageOutputDirPath, appName + '.app')
      bundledResourcesPath = path.join(packagedAppPath, 'Contents', 'Resources')
      setAtomHelperVersion(packagedAppPath)
    } else if (process.platform === 'linux') {
      packagedAppPath = packageOutputDirPath
      bundledResourcesPath = path.join(packagedAppPath, 'resources')
    } else {
      throw new Error('TODO: handle this case!')
    }

    return copyNonASARResources(packagedAppPath, bundledResourcesPath).then(() => {
      console.log(`Application bundle created at ${packagedAppPath}`)
      return packagedAppPath
    })
  })
}

function copyNonASARResources (packagedAppPath, bundledResourcesPath) {
  const bundledShellCommandsPath = path.join(bundledResourcesPath, 'app')
  console.log(`Copying shell commands to ${bundledShellCommandsPath}...`)
  fs.copySync(
    path.join(CONFIG.repositoryRootPath, 'apm', 'node_modules', 'atom-package-manager'),
    path.join(bundledShellCommandsPath, 'apm'),
    {filter: includePathInPackagedApp}
  )
  if (process.platform !== 'win32') {
    // Existing symlinks on user systems point to an outdated path, so just symlink it to the real location of the apm binary.
    // TODO: Change command installer to point to appropriate path and remove this fallback after a few releases.
    fs.symlinkSync(path.join('..', '..', 'bin', 'apm'), path.join(bundledShellCommandsPath, 'apm', 'node_modules', '.bin', 'apm'))
    fs.copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), path.join(bundledShellCommandsPath, 'atom.sh'))
  }
  if (process.platform === 'darwin') {
    fs.copySync(path.join(CONFIG.repositoryRootPath, 'resources', 'mac', 'file.icns'), path.join(bundledResourcesPath, 'file.icns'))
  } else if (process.platform === 'linux') {
    fs.copySync(path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'png', '1024.png'), path.join(packagedAppPath, 'atom.png'))
  }

  console.log(`Writing LICENSE.md to ${bundledResourcesPath}...`)
  return getLicenseText().then((licenseText) => {
    fs.writeFileSync(path.join(bundledResourcesPath, 'LICENSE.md'), licenseText)
  })
}

function setAtomHelperVersion (packagedAppPath) {
  const frameworksPath = path.join(packagedAppPath, 'Contents', 'Frameworks')
  const helperPListPath = path.join(frameworksPath, 'Atom Helper.app', 'Contents', 'Info.plist')
  console.log(`Setting Atom Helper Version for ${helperPListPath}...`)
  childProcess.spawnSync('/usr/libexec/PlistBuddy', ['-c', 'Set CFBundleVersion', CONFIG.appMetadata.version, helperPListPath])
  childProcess.spawnSync('/usr/libexec/PlistBuddy', ['-c', 'Set CFBundleShortVersionString', CONFIG.appMetadata.version, helperPListPath])
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

function getSignOptions () {
  if (process.env.CI) {
    return {identity: 'GitHub'}
  } else {
    return null
  }
}

function getIcon () {
  switch (process.platform) {
    case 'darwin':
      return path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'atom.icns')
    case 'linux':
      // Don't pass an icon, as the dock/window list icon is set via the icon
      // option in the BrowserWindow constructor in atom-window.coffee.
      return null
    default:
      throw new Error("Handle other platforms!")
  }
}

function runPackager (options) {
  return new Promise((resolve, reject) => {
    electronPackager(options, (err, packageOutputDirPaths) => {
      if (err) {
        reject(err)
        throw new Error(err)
      } else {
        assert(packageOutputDirPaths.length === 1, 'Generated more than one electron application!')
        resolve(packageOutputDirPaths[0])
      }
    })
  })
}
