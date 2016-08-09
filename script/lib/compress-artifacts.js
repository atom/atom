'use strict'

const childProcess = require('child_process')
const fs = require('fs-extra')
const path = require('path')

const CONFIG = require('../config')

module.exports = function (packagedAppPath) {
  let appArchiveName
  if (process.platform === 'darwin') {
    appArchiveName = 'atom-mac.zip'
  } else if (process.platform === 'win32') {
    appArchiveName = 'atom-windows.zip'
  } else {
    appArchiveName = 'atom-amd64.tar.gz'
  }
  const appArchivePath = path.join(CONFIG.buildOutputPath, appArchiveName)
  compress(packagedAppPath, appArchivePath)

  if (process.platform === 'darwin') {
    const symbolsArchivePath = path.join(CONFIG.buildOutputPath, 'atom-mac-symbols.zip')
    compress(CONFIG.symbolsPath, symbolsArchivePath)
  }
}

function compress (inputDirPath, outputArchivePath) {
  if (fs.existsSync(outputArchivePath)) {
    console.log(`Deleting "${outputArchivePath}"`)
    fs.removeSync(outputArchivePath)
  }

  console.log(`Compressing "${inputDirPath}" to "${outputArchivePath}"`)
  let compressCommand, compressArguments
  if (process.platform === 'darwin') {
    compressCommand = 'zip'
    compressArguments = ['-r', '--symlinks']
  } else if (process.platform === 'win32') {
    compressCommand = '7z.exe'
    compressArguments = ['a', '-r']
  } else {
    compressCommand = 'tar'
    compressArguments = ['caf']
  }
  compressArguments.push(outputArchivePath, path.basename(inputDirPath))
  childProcess.spawnSync(compressCommand, compressArguments, {cwd: path.dirname(inputDirPath)})
}
