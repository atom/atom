'use strict'

const fs = require('fs-extra')
const handleTilde = require('./handle-tilde')
const path = require('path')
const template = require('lodash.template')
const startCase = require('lodash.startcase')

const CONFIG = require('../config')

function install (installationDirPath, packagedAppFileName, packagedAppPath) {
  if (fs.existsSync(installationDirPath)) {
    console.log(`Removing previously installed "${packagedAppFileName}" at "${installationDirPath}"`)
    fs.removeSync(installationDirPath)
  }

  console.log(`Installing "${packagedAppFileName}" at "${installationDirPath}"`)
  fs.copySync(packagedAppPath, installationDirPath)
}


module.exports = function (packagedAppPath, installDir) {
  const packagedAppFileName = path.basename(packagedAppPath)
  if (process.platform === 'darwin') {
    const installPrefix = installDir !== '' ? handleTilde(installDir) : path.join(path.sep, 'Applications')
    const installationDirPath = path.join(installPrefix, packagedAppFileName)
    install(installationDirPath, packagedAppFileName, packagedAppPath)
  } else if (process.platform === 'win32') {
    const installPrefix = installDir !== '' ? installDir : process.env.LOCALAPPDATA
    const installationDirPath = path.join(installPrefix, packagedAppFileName, 'app-dev')
    try {
      install(installationDirPath, packagedAppFileName, packagedAppPath)
    } catch (e) {
      console.log(`Administrator elevation required to install into "${installationDirPath}"`)
      const fsAdmin = require('fs-admin')
      return new Promise((resolve, reject) => {
        fsAdmin.recursiveCopy(packagedAppPath, installationDirPath, (error) => {
          error ? reject(error) : resolve()
        })
      })
    }
  } else {
    const atomExecutableName = CONFIG.channel === 'stable' ? 'atom' : 'atom-' + CONFIG.channel
    const apmExecutableName = CONFIG.channel === 'stable' ? 'apm' : 'apm-' + CONFIG.channel
    const appName = CONFIG.channel === 'stable' ? 'Atom' : startCase('Atom ' + CONFIG.channel)
    const appDescription = CONFIG.appMetadata.description
    const prefixDirPath = installDir !== '' ? handleTilde(installDir) : path.join('/usr', 'local')
    const shareDirPath = path.join(prefixDirPath, 'share')
    const installationDirPath = path.join(shareDirPath, atomExecutableName)
    const applicationsDirPath = path.join(shareDirPath, 'applications')

    const binDirPath = path.join(prefixDirPath, 'bin')

    fs.mkdirpSync(applicationsDirPath)
    fs.mkdirpSync(binDirPath)

    install(installationDirPath, packagedAppFileName, packagedAppPath)

    { // Install xdg desktop file
      const desktopEntryPath = path.join(applicationsDirPath, `${atomExecutableName}.desktop`)
      if (fs.existsSync(desktopEntryPath)) {
        console.log(`Removing existing desktop entry file at "${desktopEntryPath}"`)
        fs.removeSync(desktopEntryPath)
      }
      console.log(`Writing desktop entry file at "${desktopEntryPath}"`)
      const iconPath = path.join(installationDirPath, 'atom.png')
      const desktopEntryTemplate = fs.readFileSync(path.join(CONFIG.repositoryRootPath, 'resources', 'linux', 'atom.desktop.in'))
      const desktopEntryContents = template(desktopEntryTemplate)({
        appName,
        appFileName: atomExecutableName,
        description: appDescription,
        installDir: prefixDirPath,
        iconPath
      })
      fs.writeFileSync(desktopEntryPath, desktopEntryContents)
    }

    { // Add atom executable to the PATH
      const atomBinDestinationPath = path.join(binDirPath, atomExecutableName)
      if (fs.existsSync(atomBinDestinationPath)) {
        console.log(`Removing existing executable at "${atomBinDestinationPath}"`)
        fs.removeSync(atomBinDestinationPath)
      }
      console.log(`Copying atom.sh to "${atomBinDestinationPath}"`)
      fs.copySync(path.join(CONFIG.repositoryRootPath, 'atom.sh'), atomBinDestinationPath)
    }

    { // Link apm executable to the PATH
      const apmBinDestinationPath = path.join(binDirPath, apmExecutableName)
      try {
        fs.lstatSync(apmBinDestinationPath)
        console.log(`Removing existing executable at "${apmBinDestinationPath}"`)
        fs.removeSync(apmBinDestinationPath)
      } catch (e) { }
      console.log(`Symlinking apm to "${apmBinDestinationPath}"`)
      fs.symlinkSync(path.join('..', 'share', atomExecutableName, 'resources', 'app', 'apm', 'node_modules', '.bin', 'apm'), apmBinDestinationPath)
    }

    console.log(`Changing permissions to 755 for "${installationDirPath}"`)
    fs.chmodSync(installationDirPath, '755')
  }

  return Promise.resolve()
}
