if (typeof snapshotResult !== 'undefined') {
  snapshotResult.setGlobals(global, process, global, {}, console, require);
}

const startTime = Date.now();
const StartupTime = require('../startup-time');
StartupTime.setStartTime();

const path = require('path');
const fs = require('fs-plus');
const CSON = require('season');
const yargs = require('yargs');
const electron = require('electron');

const args = yargs(process.argv)
  .alias('d', 'dev')
  .alias('t', 'test')
  .alias('r', 'resource-path').argv;

function isAtomRepoPath(repoPath) {
  let packageJsonPath = path.join(repoPath, 'package.json');
  if (fs.statSyncNoException(packageJsonPath)) {
    try {
      let packageJson = CSON.readFileSync(packageJsonPath);
      return packageJson.name === 'atom';
    } catch (e) {
      return false;
    }
  }

  return false;
}

let resourcePath;
let devResourcePath;

if (args.resourcePath) {
  resourcePath = args.resourcePath;
  devResourcePath = resourcePath;
} else {
  const stableResourcePath = path.dirname(path.dirname(__dirname));
  const defaultRepositoryPath = path.join(
    electron.app.getPath('home'),
    'github',
    'atom'
  );

  if (process.env.ATOM_DEV_RESOURCE_PATH) {
    devResourcePath = process.env.ATOM_DEV_RESOURCE_PATH;
  } else if (isAtomRepoPath(process.cwd())) {
    devResourcePath = process.cwd();
  } else if (fs.statSyncNoException(defaultRepositoryPath)) {
    devResourcePath = defaultRepositoryPath;
  } else {
    devResourcePath = stableResourcePath;
  }

  if (args.dev || args.test || args.benchmark || args.benchmarkTest) {
    resourcePath = devResourcePath;
  } else {
    resourcePath = stableResourcePath;
  }
}

const start = require(path.join(resourcePath, 'src', 'main-process', 'start'));
start(resourcePath, devResourcePath, startTime);
