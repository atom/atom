if (typeof snapshotResult !== 'undefined') {
  snapshotResult.setGlobals(global, process, global, {}, console, require)
}

const startTime = Date.now()

const path = require('path')
const yargs = require('yargs')
const getDevResourcePath = require('./get-dev-resource-path')

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
  if (args.dev || args.test || args.benchmark || args.benchmarkTest) {
    resourcePath = getDevResourcePath() || stableResourcePath
  } else {
    resourcePath = stableResourcePath
  }
}

const start = require(path.join(resourcePath, 'src', 'main-process', 'start'))
start(resourcePath, startTime)
