// This module exports paths, names, and other metadata that is referenced
// throughout the build.

'use strict'

const path = require('path')

const appMetadata = require('../package.json')

const repositoryRootPath = path.resolve(__dirname, '..')
const buildOutputPath = path.join(repositoryRootPath, 'out')
const intermediateAppPath = path.join(buildOutputPath, 'app')
const intermediateShellCommandsPath = path.join(buildOutputPath, 'shell')
const cachePath = path.join(repositoryRootPath, 'cache')
const channel = getChannel()

module.exports = {
  appMetadata, channel,
  repositoryRootPath, buildOutputPath, intermediateAppPath, intermediateShellCommandsPath,
  cachePath
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
