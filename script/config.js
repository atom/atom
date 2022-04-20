// This module exports paths, names, and other metadata that is referenced
// throughout the build.

'use strict';

const path = require('path');
const spawnSync = require('./lib/spawn-sync');

const repositoryRootPath = path.resolve(__dirname, '..');
const apmRootPath = path.join(repositoryRootPath, 'apm');
const scriptRootPath = path.join(repositoryRootPath, 'script');
const buildOutputPath = path.join(repositoryRootPath, 'out');
const docsOutputPath = path.join(repositoryRootPath, 'docs', 'output');
const intermediateAppPath = path.join(buildOutputPath, 'app');
const symbolsPath = path.join(buildOutputPath, 'symbols');
const electronDownloadPath = path.join(repositoryRootPath, 'electron');
const homeDirPath = process.env.HOME || process.env.USERPROFILE;
const atomHomeDirPath =
  process.env.ATOM_HOME || path.join(homeDirPath, '.atom');

const appMetadata = require(path.join(repositoryRootPath, 'package.json'));
const apmMetadata = require(path.join(apmRootPath, 'package.json'));
const computedAppVersion = computeAppVersion(
  process.env.ATOM_RELEASE_VERSION || appMetadata.version
);
const channel = getChannel(computedAppVersion);
const appName = getAppName(channel);
const executableName = getExecutableName(channel, appName);
const channelName = getChannelName(channel);

// Sets the installation jobs to run maximally in parallel if the user has
// not already configured this. This is applied just by requiring this file.
if (process.env.npm_config_jobs === undefined) {
  process.env.npm_config_jobs = 'max';
}

module.exports = {
  appMetadata,
  apmMetadata,
  channel,
  channelName,
  appName,
  executableName,
  computedAppVersion,
  repositoryRootPath,
  apmRootPath,
  scriptRootPath,
  buildOutputPath,
  docsOutputPath,
  intermediateAppPath,
  symbolsPath,
  electronDownloadPath,
  atomHomeDirPath,
  homeDirPath,
  getApmBinPath,
  getNpmBinPath,
  getLocalNpmBinPath,
  snapshotAuxiliaryData: {}
};

function getChannelName(channel) {
  return channel === 'stable' ? 'atom' : `atom-${channel}`;
}

function getChannel(version) {
  const match = version.match(/\d+\.\d+\.\d+(-([a-z]+)(\d+|-\w{4,})?)?$/);
  if (!match) {
    throw new Error(`Found incorrectly formatted Atom version ${version}`);
  } else if (match[2]) {
    return match[2];
  }

  return 'stable';
}

function getAppName(channel) {
  return channel === 'stable'
    ? 'Atom'
    : `Atom ${process.env.ATOM_CHANNEL_DISPLAY_NAME ||
        channel.charAt(0).toUpperCase() + channel.slice(1)}`;
}

function getExecutableName(channel, appName) {
  if (process.platform === 'darwin') {
    return appName;
  } else if (process.platform === 'win32') {
    return channel === 'stable' ? 'atom.exe' : `atom-${channel}.exe`;
  } else {
    return 'atom';
  }
}

function computeAppVersion(version) {
  if (version.match(/-dev$/)) {
    const result = spawnSync('git', ['rev-parse', '--short', 'HEAD'], {
      cwd: repositoryRootPath
    });
    const commitHash = result.stdout.toString().trim();
    version += '-' + commitHash;
  }
  return version;
}

function getApmBinPath() {
  const apmBinName = process.platform === 'win32' ? 'apm.cmd' : 'apm';
  return path.join(
    apmRootPath,
    'node_modules',
    'atom-package-manager',
    'bin',
    apmBinName
  );
}

function getNpmBinPath() {
  return process.platform === 'win32' ? 'npm.cmd' : 'npm';
}

function getLocalNpmBinPath() {
  const npmBinName = process.platform === 'win32' ? 'npm.cmd' : 'npm';
  const localNpmBinPath = path.resolve(
    repositoryRootPath,
    'script',
    'node_modules',
    '.bin',
    npmBinName
  );
  return localNpmBinPath;
}
