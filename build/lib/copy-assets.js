// This module exports a function that copies all the static assets into the
// appropriate location in the build output directory.

'use strict'

const path = require('path')
const fs = require('fs-extra')
const computeDestinationPath = require('./compute-destination-path')
const CONFIG = require('../config')
const glob = require('glob')

module.exports = function () {
  console.log('Copying assets...');
  const srcPaths = [
    path.join(CONFIG.repositoryRootPath, 'dot-atom'),
    path.join(CONFIG.repositoryRootPath, 'exports'),
    path.join(CONFIG.repositoryRootPath, 'node_modules'),
    path.join(CONFIG.repositoryRootPath, 'static'),
    path.join(CONFIG.repositoryRootPath, 'src'),
    path.join(CONFIG.repositoryRootPath, 'vendor')
  ]
  srcPaths.concat(glob.sync(path.join(CONFIG.repositoryRootPath, 'spec', '*.*'), {ignore: '**/*-spec.*'}))
  for (let srcPath of srcPaths) {
    fs.copySync(srcPath, computeDestinationPath(srcPath))
  }
}
