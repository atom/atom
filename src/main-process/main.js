if (typeof snapshotResult !== 'undefined') {
  snapshotResult.setGlobals(global, process, {}, require)
}

const startTime = Date.now()

const electron = require('electron')
const fs = require('fs')
const path = require('path')
const yargs = require('yargs')

const args =
  yargs(process.argv)
    .alias('d', 'dev')
    .alias('t', 'test')
    .argv

let resourcePath

if (args.resourcePath) {
  resourcePath = args.resourcePath
} else {
  const stableResourcePath = path.dirname(path.dirname(__dirname))
  const defaultRepositoryPath = path.join(electron.app.getPath('home'), 'github', 'atom')

  if (args.dev || args.test || args.benchmark || args.benchmarkTest) {
    if (process.env.ATOM_DEV_RESOURCE_PATH) {
      resourcePath = process.env.ATOM_DEV_RESOURCE_PATH
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
