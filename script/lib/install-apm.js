'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

function installApm(ci) {
  console.log('Installing apm');
  // npm ci leaves apm with a bunch of unmet dependencies
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(),
    ['--global-style', '--loglevel=error', 'install'],
    { env: process.env, cwd: CONFIG.apmRootPath }
  );
  childProcess.execFileSync(CONFIG.getApmBinPath(), ['--version'], {
    stdio: 'inherit'
  });
}

const { expose } = require(`${CONFIG.scriptRunnerModulesPath}/threads/worker`);
expose(installApm);
module.exports = installApm;
