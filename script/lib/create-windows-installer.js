'use strict'

const downloadGithubRawFile = require('./download-github-raw-file')
const electronInstaller = require('electron-winstaller')
const fs = require('fs-extra')
const os = require('os')
const path = require('path')

const CONFIG = require('../config')

module.exports = function (packagedAppPath, codeSign) {
  console.log(`Creating Windows Installer for ${packagedAppPath}`)
  const options = {
    appDirectory: packagedAppPath,
    authors: 'GitHub Inc.',
    iconUrl: `https://raw.githubusercontent.com/atom/atom/master/resources/app-icons/${CONFIG.channel}/atom.ico`,
    loadingGif: path.join(CONFIG.repositoryRootPath, 'resources', 'win', 'loading.gif'),
    outputDirectory: CONFIG.buildOutputPath,
    remoteReleases: `https://atom.io/api/updates?version=${CONFIG.appMetadata.version}`,
    setupIcon: path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'atom.ico'),
    title: CONFIG.channel === 'beta' ? 'Atom Beta' : 'Atom'
  }

  if (codeSign && process.env.WIN_P12KEY_URL) {
    const certPath = path.join(os.tmpdir(), 'win.p12')
    downloadGithubRawFile(process.env.WIN_P12KEY_URL, certPath)
    const deleteCertificate = function () {
      console.log(`Deleting certificate at ${certPath}`)
      fs.removeSync(certPath)
    }
    options.certificateFile = certPath
    options.certificatePassword = process.env.WIN_P12KEY_PASSWORD
    return electronInstaller.createWindowsInstaller(options).then(deleteCertificate, deleteCertificate)
  } else {
    console.log('Skipping code-signing. Specify the --code-sign option and provide a WIN_P12KEY_URL environment variable to perform code-signing'.gray)
    return electronInstaller.createWindowsInstaller(options)
  }
}
