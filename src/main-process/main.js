if (typeof snapshotResult !== 'undefined') {
  snapshotResult.setGlobals(global, process, global, {}, console, require)
}

const startTime = Date.now()

const path = require('path')
const fs = require('fs-plus')
const CSON = require('season')
const yargs = require('yargs')
const electron = require('electron')

const args =
  yargs(process.argv)
    .alias('d', 'dev')
    .alias('t', 'test')
    .argv

function isAtomRepoPath (repoPath) {
  let packageJsonPath = path.join(repoPath, 'package.json')
  if (fs.statSyncNoException(packageJsonPath)) {
    let packageJson = CSON.readFileSync(packageJsonPath)
    return packageJson.name === 'atom'
  }

  return false
}

let resourcePath

if (args.resourcePath) {
  resourcePath = args.resourcePath
} else {
  const stableResourcePath = path.dirname(path.dirname(__dirname))
  const defaultRepositoryPath = path.join(electron.app.getPath('home'), 'github', 'atom')

  if (args.dev || args.test || args.benchmark || args.benchmarkTest) {
    if (process.env.ATOM_DEV_RESOURCE_PATH) {
      resourcePath = process.env.ATOM_DEV_RESOURCE_PATH
    } else if (isAtomRepoPath(process.cwd())) {
      resourcePath = process.cwd()
    } else if (fs.statSyncNoException(defaultRepositoryPath)) {
      resourcePath = defaultRepositoryPath
    } else {
      resourcePath = stableResourcePath
    }
  } else {
    resourcePath = stableResourcePath
  }
}

const start = require(path.join(resourcePath, 'src', 'main-process', 'start'))
start(resourcePath, startTime)
