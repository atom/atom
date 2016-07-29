// This module exports paths, names, and other metadata that is referenced
// throughout the build.

'use strict'

const path = require('path')
const childProcess = require('child_process')

const appMetadata = require('../package.json')

const repositoryRootPath = path.resolve(__dirname, '..')
const buildOutputPath = path.join(repositoryRootPath, 'out')
const intermediateAppPath = path.join(buildOutputPath, 'app')
const cachePath = path.join(repositoryRootPath, 'cache')

module.exports = {
  appMetadata, getAppVersion, getChannel,
  repositoryRootPath, buildOutputPath, intermediateAppPath,
  cachePath
}

function getAppVersion () {
  let version = appMetadata.version
  if (getChannel() === 'dev') {
    const result = childProcess.spawnSync('git', ['rev-parse', '--short', 'HEAD'], {cwd: repositoryRootPath})
    const commitHash = result.stdout.toString().trim()
    version += '-' + commitHash
  }
  return version
}

function getChannel () {
  if (appMetadata.version.match(/dev/) || isBuildingPR()) {
    return 'dev'
  } else if (appMetadata.version.match(/beta/)) {
    return 'beta'
  } else {
    return 'stable'
  }
}

function isBuildingPR () {
  return (
    process.env.APPVEYOR_PULL_REQUEST_NUMBER ||
    process.env.TRAVIS_PULL_REQUEST ||
    process.env.CI_PULL_REQUEST
  )
}
