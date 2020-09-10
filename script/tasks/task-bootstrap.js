'use strict';

const CONFIG = require('../config');
const childProcess = require('child_process');
const cleanDependencies = require('./task-clean-dependencies');
const deleteMsbuildFromPath = require('./task-delete-msbuild-from-path');
const dependenciesFingerprint = require('./task-dependencies-fingerprint');
const installApm = require('./task-install-apm');
const runApmInstall = require('./task-run-apm-install');
const installScriptDependencies = require('./task-install-script-dependencies');
const verifyMachineRequirements = require('./task-verify-machine-requirements');

module.exports = function(task) {
  task.start('Bootstrap');

  // We can't use yargs until installScriptDependencies() is executed, so...
  let ci = process.argv.indexOf('--ci') !== -1;

  if (
    !ci &&
    process.env.CI === 'true' &&
    process.argv.indexOf('--no-ci') === -1
  ) {
    task.info(
      'Automatically enabling --ci because CI is set in the environment'
    );
    ci = true;
  }

  verifyMachineRequirements(ci, task.subtask());

  if (dependenciesFingerprint.isOutdated()) {
    cleanDependencies(task.subtask());
  }

  if (process.platform === 'win32') deleteMsbuildFromPath(task.subtask());

  installScriptDependencies(ci, task.subtask());
  installApm(ci, task.subtask());

  childProcess.execFileSync(CONFIG.getApmBinPath(), ['--version'], {
    stdio: 'inherit'
  });

  runApmInstall(CONFIG.repositoryRootPath, ci, undefined, task.subtask());

  dependenciesFingerprint.write(task.subtask());

  task.done();
};
