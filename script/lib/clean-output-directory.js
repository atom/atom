const fs = require('fs-extra')
const path = require('path')
const CONFIG = require('../config')

module.exports = function () {
  if (fs.existsSync(CONFIG.buildOutputPath)) {
    console.log(`Cleaning ${CONFIG.buildOutputPath}`)
    fs.removeSync(CONFIG.buildOutputPath)
  }
}
