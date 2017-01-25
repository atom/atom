'use strict'

const downloadFileFromGithub = require('./download-file-from-github')
const electronInstaller = require('electron-winstaller')
const fs = require('fs-extra')
const glob = require('glob')
const os = require('os')
const path = require('path')
const spawnSync = require('./spawn-sync')

const CONFIG = require('../config')

module.exports = function (packagedAppPath, codeSign) {
  const archSuffix = process.arch === 'ia32' ? '' : '-' + process.arch
  const options = {
    appDirectory: packagedAppPath,
    authors: 'GitHub Inc.',
    iconUrl: `https://raw.githubusercontent.com/atom/atom/master/resources/app-icons/${CONFIG.channel}/atom.ico`,
    loadingGif: path.join(CONFIG.repositoryRootPath, 'resources', 'win', 'loading.gif'),
    outputDirectory: CONFIG.buildOutputPath,
    remoteReleases: `https://atom.io/api/updates${archSuffix}`,
    setupIcon: path.join(CONFIG.repositoryRootPath, 'resources', 'app-icons', CONFIG.channel, 'atom.ico')
  }

  const signing = codeSign && (process.env.ATOM_WIN_CODE_SIGNING_CERT_DOWNLOAD_URL || process.env.ATOM_WIN_CODE_SIGNING_CERT_PATH)
  let certPath = ATOM_WIN_CODE_SIGNING_CERT_PATH;
  if (!certPath) {
    certPath = path.join(os.tmpdir(), 'win.p12')
    downloadFileFromGithub(process.env.ATOM_WIN_CODE_SIGNING_CERT_DOWNLOAD_URL, certPath)
  }

  if (signing) {
    var signParams = []
    signParams.push(`/f ${certPath}`) // Signing cert file
    signParams.push(`/p ${process.env.ATOM_WIN_CODE_SIGNING_CERT_PASSWORD}`) // Signing cert password
    signParams.push('/fd sha256') // File digest algorithm
    signParams.push('/tr http://timestamp.digicert.com') // Time stamp server
    signParams.push('/td sha256') // Times stamp algorithm
    options.signWithParams = signParams.join(' ')
  } else {
    console.log('Skipping code-signing. Specify the --code-sign option and provide a ATOM_WIN_CODE_SIGNING_CERT_DOWNLOAD_URL environment variable to perform code-signing'.gray)
  }

  const cleanUp = function () {
    if (fs.existsSync(certPath) && !process.env.ATOM_WIN_CODE_SIGNING_CERT_PATH) {
      console.log(`Deleting certificate at ${certPath}`)
      fs.removeSync(certPath)
    }

    for (let nupkgPath of glob.sync(`${CONFIG.buildOutputPath}/*.nupkg`)) {
      if (!nupkgPath.includes(CONFIG.appMetadata.version)) {
        console.log(`Deleting downloaded nupkg for previous version at ${nupkgPath} to prevent it from being stored as an artifact`)
        fs.removeSync(nupkgPath)
      }
    }
  }

  // Squirrel signs its own copy of the executables but we need them for the portable ZIP
  const extractSignedExes = function() {
    if (signing) {
      for (let nupkgPath of glob.sync(`${CONFIG.buildOutputPath}/*-full.nupkg`)) {
        if (nupkgPath.includes(CONFIG.appMetadata.version)) {
          nupkgPath = path.resolve(nupkgPath) // Switch from forward-slash notation
          console.log(`Extracting signed executables from ${nupkgPath} for use in portable zip`)
          spawnSync('7z.exe', ['e', nupkgPath, 'lib\\net45\\*.exe', '-aoa', `-o${packagedAppPath}`])
          spawnSync(process.env.COMSPEC, ['/c', 'move', '/y', path.join(packagedAppPath, 'squirrel.exe'), path.join(packagedAppPath, 'update.exe')])
          return
        }
      }
    }
  }

  console.log(`Creating Windows Installer for ${packagedAppPath}`)
  return electronInstaller.createWindowsInstaller(options)
    .then(extractSignedExes, function (error) {
      console.log(`Extracting signed executables failed:\n${error}`)
      cleanUp()
    })
    .then(cleanUp, function (error) {
      console.log(`Windows installer creation failed:\n${error}`)
      cleanUp()
    })
}
