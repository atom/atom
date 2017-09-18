// This module exports paths, names, and other metadata that is referenced
// throughout the build.

'use strict'

const fs = require('fs')
const path = require('path')

const repositoryRootPath = path.resolve(__dirname, '..')
const apmRootPath = path.join(repositoryRootPath, 'apm')
const scriptRootPath = path.join(repositoryRootPath, 'script')
const buildOutputPath = path.join(repositoryRootPath, 'out')
const docsOutputPath = path.join(repositoryRootPath, 'docs', 'output')
const intermediateAppPath = path.join(buildOutputPath, 'app')
const symbolsPath = path.join(buildOutputPath, 'symbols')
const electronDownloadPath = path.join(repositoryRootPath, 'electron')
const homeDirPath = process.env.HOME || process.env.USERPROFILE
const atomHomeDirPath = process.env.ATOM_HOME || path.join(homeDirPath, '.atom')

const appMetadata = require(path.join(repositoryRootPath, 'package.json'))
const apmMetadata = require(path.join(apmRootPath, 'package.json'))
const channel = getChannel()

module.exports = {
  appMetadata,
  apmMetadata,
  channel,
  repositoryRootPath,
  apmRootPath,
  scriptRootPath,
  buildOutputPath,
  docsOutputPath,
  intermediateAppPath,
  symbolsPath,
  electronDownloadPath,
  atomHomeDirPath,
  homeDirPath,
  getApmBinPath,
  getNpmBinPath,
  snapshotAuxiliaryData: {}
}

function getChannel () {
  if (appMetadata.version.match(/dev/)) {
    return 'dev'
  } else if (appMetadata.version.match(/beta/)) {
    return 'beta'
  } else {
    return 'stable'
  }
}

function getApmBinPath () {
  const apmBinName = process.platform === 'win32' ? 'apm.cmd' : 'apm'
  return path.join(apmRootPath, 'node_modules', 'atom-package-manager', 'bin', apmBinName)
}

function getNpmBinPath () {
  const npmBinName = process.platform === 'win32' ? 'npm.cmd' : 'npm'
  const localNpmBinPath = path.resolve(repositoryRootPath, 'script', 'node_modules', '.bin', npmBinName)
  return fs.existsSync(localNpmBinPath) ? localNpmBinPath : npmBinName
}
