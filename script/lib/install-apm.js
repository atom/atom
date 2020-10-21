'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

function installApm(ci = false, showVersion = true) {
  console.log('Installing apm');
  // npm ci leaves apm with a bunch of unmet dependencies
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(),
    ['--global-style', '--loglevel=error', 'install'],
    { env: process.env, cwd: CONFIG.apmRootPath }
  );
  if (showVersion) {
    const apmVersionEnv = {
      ...process.env,
      ATOM_RESOURCE_PATH: CONFIG.repositoryRootPath
    };
    childProcess.execFileSync(CONFIG.getApmBinPath(), ['--version'], {
      stdio: 'inherit',
      env: apmVersionEnv
    });
  }
}

const { expose } = require(`${CONFIG.scriptRunnerModulesPath}/threads/worker`);
expose(installApm);
module.exports = installApm;
