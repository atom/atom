'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

process.env.ELECTRON_CUSTOM_VERSION = CONFIG.appMetadata.electronVersion;

function installScriptDependencies(ci) {
  console.log('Installing script dependencies');
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(ci),
    ['--loglevel=error', ci ? 'ci' : 'install'],
    { env: process.env, cwd: CONFIG.scriptRootPath }
  );
}

const { expose } = require(`${CONFIG.scriptRunnerModulesPath}/threads/worker`);
expose(installScriptDependencies);
module.exports = installScriptDependencies;
