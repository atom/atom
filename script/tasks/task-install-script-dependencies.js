'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');
const { DefaultTask } = require('../lib/task');

process.env.ELECTRON_CUSTOM_VERSION = CONFIG.appMetadata.electronVersion;

module.exports = function(ci, task = new DefaultTask()) {
  task.start('Install script dependencies');

  task.log('Installing script dependencies');
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(ci),
    ['--loglevel=error', ci ? 'ci' : 'install'],
    { env: process.env, cwd: CONFIG.scriptRootPath }
  );

  task.done();
};
