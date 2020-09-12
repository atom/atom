'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

process.env.ELECTRON_CUSTOM_VERSION = CONFIG.appMetadata.electronVersion;

function installScriptRunnerDependencies(ci) {
  console.log('Installing script runner dependencies');
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(ci),
    ['--loglevel=error', ci ? 'ci' : 'install'],
    { env: process.env, cwd: CONFIG.scriptRunnerRootPath }
  );
}

module.exports = installScriptRunnerDependencies;
