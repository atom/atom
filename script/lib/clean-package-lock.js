// This module exports a function that deletes all `package-lock.json` files that do
// not exist under a `node_modules` directory.

'use strict'

const CONFIG = require('../config')
const fs = require('fs-extra')
const glob = require('glob')
const path = require('path')

module.exports = function () {
  console.log('Deleting problematic package-lock.json files')
  let paths = glob.sync(path.join(CONFIG.repositoryRootPath, '**', 'package-lock.json'), {ignore: [path.join('**', 'node_modules', '**'), path.join('**', 'vsts', '**')]})

  for (let path of paths) {
    fs.unlinkSync(path)
  }
}
