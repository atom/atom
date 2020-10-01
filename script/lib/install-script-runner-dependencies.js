'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

function installScriptRunnerDependencies(ci) {
  console.log('Installing script runner dependencies');
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(ci),
    ['--loglevel=error', ci ? 'ci' : 'install'],
    { env: process.env, cwd: CONFIG.scriptRunnerRootPath }
  );
}

module.exports = installScriptRunnerDependencies;
