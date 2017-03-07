const fs = require('fs-extra')
const path = require('path')
const CONFIG = require('../config')

module.exports = function () {
  let srcPaths = [
    path.join('benchmarks', 'benchmark-runner.js'),
    path.join('dot-atom'),
    path.join('exports'),
    path.join('package.json'),
    path.join('static'),
    path.join('src'),
    path.join('vendor')
  ]

  for (const srcPath of srcPaths) {
    fs.removeSync(path.join(CONFIG.intermediateAppPath, srcPath))
  }
}
