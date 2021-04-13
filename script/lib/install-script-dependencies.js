'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

// Recognised by '@electron/get', used by the 'electron-mksnapshot' and 'electron-chromedriver' dependencies
process.env.ELECTRON_CUSTOM_VERSION = CONFIG.appMetadata.electronVersion;

module.exports = function(ci) {
  console.log('Installing script dependencies');
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(ci),
    ['--loglevel=error', ci ? 'ci' : 'install'],
    { env: process.env, cwd: CONFIG.scriptRootPath }
  );
};
