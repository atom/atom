'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

module.exports = function(ci) {
  if (ci) {
    // Tell apm not to dedupe its own dependencies during its
    // postinstall script. (Deduping during `npm ci` runs is broken.)
    process.env.NO_APM_DEDUPE = 'true';
  }
  console.log('Installing apm');
  childProcess.execFileSync(
    CONFIG.getLocalNpmBinPath(),
    ['--global-style', '--loglevel=error', ci ? 'ci' : 'install'],
    { env: process.env, cwd: CONFIG.apmRootPath }
  );
};
