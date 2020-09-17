'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

module.exports = function(ci) {
  console.log('Installing apm');
  // npm ci leaves apm with a bunch of unmet dependencies
  process.env.npm_config_jobs = "max";
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(),
    ['--global-style', '--loglevel=error', 'install'],
    { env: process.env, cwd: CONFIG.apmRootPath }
  );
};
