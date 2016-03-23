// Takes an absolute path, relativizes it based on the repository root, then
// makes it absolute again in the output app path.

'use strict'

const path = require('path')
const CONFIG = require('../config')

module.exports =
function computeDestinationPath (srcPath) {
  let relativePath = path.relative(CONFIG.repositoryRootPath, srcPath)
  return path.join(CONFIG.electronAppPath, relativePath)
}
