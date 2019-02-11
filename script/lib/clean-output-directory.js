const fs = require('fs-extra')
const CONFIG = require('../config')

module.exports = async function () {
  if (await fs.pathExists(CONFIG.buildOutputPath)) {
    console.log(`Cleaning ${CONFIG.buildOutputPath}`)
    await fs.remove(CONFIG.buildOutputPath)
  }
}
