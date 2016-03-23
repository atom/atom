// This module exports paths, names, and other metadata that is referenced
// throughout the build.

'use strict'

const path = require('path')

const appMetadata = require('../package.json')

const repositoryRootPath = path.resolve(__dirname, '..')
const buildOutputPath = path.join(repositoryRootPath, 'out')

const appName = appMetadata.productName
const appFileName = appMetadata.name

let electronRootPath, electronAppPath

switch (process.platform) {
  case 'darwin':
    electronRootPath = path.join(buildOutputPath, appName, 'Contents')
    electronAppPath = path.join(electronRootPath, 'Resources', 'app')
    break;
}

module.exports = {
  appMetadata,
  repositoryRootPath, buildOutputPath,
  appName, appFileName,
  electronRootPath, electronAppPath
}
