'use strict'

const fs = require('fs-extra')
const path = require('path')
const spawnSync = require('./spawn-sync')

const CONFIG = require('../config')

module.exports = function (packagedAppPath) {
  let appArchiveName
  if (process.platform === 'darwin') {
    appArchiveName = 'atom-mac.zip'
  } else if (process.platform === 'win32') {
    appArchiveName = 'atom-windows.zip'
  } else {
    let arch
    if (process.arch === 'ia32') {
      arch = 'i386'
    } else if (process.arch === 'x64') {
      arch = 'amd64'
    } else {
      arch = process.arch
    }
    appArchiveName = `atom-${arch}.tar.gz`
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
  spawnSync(compressCommand, compressArguments, {cwd: path.dirname(inputDirPath)})
}
