'use strict'

const path = require('path')
const fs = require('fs-plus')
const CSON = require('season')
const electron = require('electron')

module.exports = function () {
  const appResourcePath = path.dirname(path.dirname(__dirname))
  const defaultRepositoryPath = path.join(electron.app.getPath('home'), 'github', 'atom')

  if (process.env.ATOM_DEV_RESOURCE_PATH) {
    return process.env.ATOM_DEV_RESOURCE_PATH
  } else if (isAtomRepoPath(process.cwd())) {
    return process.cwd()
  } else if (fs.statSyncNoException(defaultRepositoryPath)) {
    return defaultRepositoryPath
  }

  return appResourcePath
}

function isAtomRepoPath (repoPath) {
  let packageJsonPath = path.join(repoPath, 'package.json')
  if (fs.statSyncNoException(packageJsonPath)) {
    let packageJson = CSON.readFileSync(packageJsonPath)
    return packageJson.name === 'atom'
  }

  return false
}
