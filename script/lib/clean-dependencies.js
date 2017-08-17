const path = require('path')

const CONFIG = require('../config')

module.exports = function () {
  // We can't require fs-extra if `script/bootstrap` has never been run, because
  // it's a third party module. This is okay because cleaning dependencies only
  // makes sense if dependencies have been installed at least once.
  const fs = require('fs-extra')

  const apmDependenciesPath = path.join(CONFIG.apmRootPath, 'node_modules')
  console.log(`Cleaning ${apmDependenciesPath}`)
  fs.removeSync(apmDependenciesPath)

  const atomDependenciesPath = path.join(CONFIG.repositoryRootPath, 'node_modules')
  console.log(`Cleaning ${atomDependenciesPath}`)
  fs.removeSync(atomDependenciesPath)

  const scriptDependenciesPath = path.join(CONFIG.scriptRootPath, 'node_modules')
  console.log(`Cleaning ${scriptDependenciesPath}`)
  fs.removeSync(scriptDependenciesPath)
}
