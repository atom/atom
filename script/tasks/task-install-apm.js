'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

module.exports = function (ci, task) {
  task.start('Install apm');

  const npmBinPath = CONFIG.getNpmBinPath();
  const cwd = CONFIG.apmRootPath;

  task.verbose(`npm bin path: ${npmBinPath}`);
  task.verbose(`cwd: ${cwd}`);

  // npm ci leaves apm with a bunch of unmet dependencies
  childProcess.execFileSync(
    npmBinPath,
    ['--global-style', '--loglevel=error', 'install'],
    { env: process.env, cwd }
  );

  task.done();
};
