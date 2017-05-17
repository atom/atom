const fs = require('fs-extra')
const path = require('path')

module.exports = function(packagePath) {
  const nodeModulesPath = path.join(packagePath, 'node_modules')
  const nodeModulesBackupPath = path.join(packagePath, 'node_modules.bak')
  if (fs.existsSync(nodeModulesBackupPath)) {
    throw new Error("Cannot back up " + nodeModulesPath + "; " + nodeModulesBackupPath + " already exists")
  }

  fs.copySync(nodeModulesPath, nodeModulesBackupPath)

  return function restoreNodeModules() {
    if (!fs.existsSync(nodeModulesBackupPath)) {
      throw new Error("Cannot restore " + nodeModulesPath + "; " + nodeModulesBackupPath + " does not exist")
    }
    fs.removeSync(nodeModulesPath)
    fs.renameSync(nodeModulesBackupPath, nodeModulesPath)
  }
}
