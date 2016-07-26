// This module exports a function that copies all the static assets into the
// appropriate location in the build output directory.

'use strict'

const path = require('path')
const fs = require('fs-extra')
const computeDestinationPath = require('./compute-destination-path')
const CONFIG = require('../config')

module.exports = function () {
  console.log('Copying static assets...');
  const sourcePaths = [
    path.join(CONFIG.repositoryRootPath, 'static'),
    path.join(CONFIG.repositoryRootPath, 'dot-atom'),
    path.join(CONFIG.repositoryRootPath, 'vendor')
  ]

  for (let srcPath of sourcePaths) {
    fs.copySync(srcPath, computeDestinationPath(srcPath))
  }
}
