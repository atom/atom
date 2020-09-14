'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

module.exports = function(ci, promise = false) {
  console.log('Installing apm');
  // npm ci leaves apm with a bunch of unmet dependencies

  if (promise) {
    return new Promise(resolve => {
      childProcess.execFile(
        CONFIG.getNpmBinPath(),
        ['--global-style', '--loglevel=error', 'install'],
        { env: process.env, cwd: CONFIG.apmRootPath },
        () => {
          console.log('Installed apm');
          resolve();
        }
      );
    });
  } else {
    childProcess.execFileSync(
      CONFIG.getNpmBinPath(),
      ['--global-style', '--loglevel=error', 'install'],
      { env: process.env, cwd: CONFIG.apmRootPath }
    );
  }
};
