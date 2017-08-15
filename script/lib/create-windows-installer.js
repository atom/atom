'use strict'

const electronInstaller = require('electron-winstaller')
const fs = require('fs-extra')
const glob = require('glob')
const path = require('path')

const CONFIG = require('../config')

module.exports = (packagedAppPath) => {
  const archSuffix = process.arch === 'ia32' ? '' : '-' + process.arch
  const options = {
    appDirectory: packagedAppPath,
    authors: 'GitHub Inc.',
    iconUrl: `https://raw.githubusercontent.com/atom/atom/master/resources/app-icons/${CONFIG.channel}/atom.ico`,
    loadingGif: path.join(CONFIG.repositoryRootPath, 'resources', 'win', 'loading.gif'),
    outputDirectory: CONFIG.buildOutputPath,
    noMsi: true,
    remoteReleases: `https://atom.io/api/updates${archSuffix}?version=${CONFIG.appMetadata.version}`,
    setupIcon: path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'atom.ico')
  }

  const cleanUp = () => {
    for (let nupkgPath of glob.sync(`${CONFIG.buildOutputPath}/*.nupkg`)) {
      if (!nupkgPath.includes(CONFIG.appMetadata.version)) {
        console.log(`Deleting downloaded nupkg for previous version at ${nupkgPath} to prevent it from being stored as an artifact`)
        fs.removeSync(nupkgPath)
      }
    }
  }

  console.log(`Creating Windows Installer for ${packagedAppPath}`)
  return electronInstaller.createWindowsInstaller(options)
    .then(cleanUp, error => {
      cleanUp()
      return Promise.reject(error)
    })
}
