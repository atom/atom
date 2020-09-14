'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

process.env.ELECTRON_CUSTOM_VERSION = CONFIG.appMetadata.electronVersion;

module.exports = function(ci) {
  return new Promise(resolve => {
    console.log('Installing script dependencies');
    childProcess.execFile(
      CONFIG.getNpmBinPath(ci),
      ['--loglevel=error', ci ? 'ci' : 'install'],
      { env: process.env, cwd: CONFIG.scriptRootPath },
      () => {
        console.log("Installed script dependencies");
        resolve()
      },
    );
  })
};
