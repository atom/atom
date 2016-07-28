// This module exports paths, names, and other metadata that is referenced
// throughout the build.

'use strict'

const path = require('path')

const appMetadata = require('../package.json')

const repositoryRootPath = path.resolve(__dirname, '..')
const buildOutputPath = path.join(repositoryRootPath, 'out')
const intermediateAppPath = path.join(buildOutputPath, 'app')
const cachePath = path.join(repositoryRootPath, 'cache')

module.exports = {
  appMetadata,
  repositoryRootPath, buildOutputPath, intermediateAppPath, cachePath
}
