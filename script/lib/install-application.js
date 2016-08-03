'use strict'

const fs = require('fs-extra')
const path = require('path')

module.exports = function (packagedAppPath) {
  if (process.platform === 'darwin') {
    const packagedAppPathFileName = path.basename(packagedAppPath)
    const installationDirPath = path.join(path.sep, 'Applications', packagedAppPathFileName)
    if (fs.existsSync(installationDirPath)) {
      console.log(`Removing previously installed ${packagedAppPathFileName} at ${installationDirPath}...`)
      fs.removeSync(installationDirPath)
    }
    console.log(`Installing ${packagedAppPath} at ${installationDirPath}...`)
    fs.copySync(packagedAppPath, installationDirPath)
  } else {
    throw new Error("Not implemented yet.")
  }
}
