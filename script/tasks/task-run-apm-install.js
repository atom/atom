'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

module.exports = function (packagePath, ci, stdioOptions, task) {
  task.start('Run apm install');

  const installEnv = Object.assign({}, process.env);
  // Set resource path so that apm can load metadata related to Atom.
  installEnv.ATOM_RESOURCE_PATH = CONFIG.repositoryRootPath;
  // Set our target (Electron) version so that node-pre-gyp can download the
  // proper binaries.
  installEnv.npm_config_target = CONFIG.appMetadata.electronVersion;

  const apmBinPath = CONFIG.getApmBinPath();

  task.verbose(`ATOM_RESOURCE_PATH: ${installEnv.ATOM_RESOURCE_PATH}`);
  task.verbose(`npm_config_target: ${installEnv.npm_config_target}`);
  task.verbose(`apm bin path: ${apmBinPath}`);

  childProcess.execFileSync(apmBinPath, [ci ? 'ci' : 'install'], {
    env: installEnv,
    cwd: packagePath,
    stdio: stdioOptions || 'inherit',
  });

  task.done();
};
