'use strict'

const fs = require('fs-extra')
const os = require('os')
const path = require('path')

const CONFIG = require('../config')

module.exports = function () {
  const cachePaths = [
    path.join(CONFIG.repositoryRootPath, 'cache'),
    path.join(CONFIG.homeDirPath, '.atom', '.node-gyp'),
    path.join(CONFIG.homeDirPath, '.atom', 'storage'),
    path.join(CONFIG.homeDirPath, '.atom', '.apm'),
    path.join(CONFIG.homeDirPath, '.atom', '.npm'),
    path.join(CONFIG.homeDirPath, '.atom', 'compile-cache'),
    path.join(CONFIG.homeDirPath, '.atom', 'atom-shell'),
    path.join(CONFIG.homeDirPath, '.atom', 'electron'),
    path.join(os.tmpdir(), 'atom-build'),
    path.join(os.tmpdir(), 'atom-cached-atom-shells')
  ]

  for (let path of cachePaths) {
    console.log(`Cleaning ${path}...`)
    fs.removeSync(path)
  }
}
