'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');
const { DefaultTask } = require('../lib/task');

module.exports = function(
  packagePath,
  ci,
  stdioOptions,
  task = new DefaultTask()
) {
  task.start('Run apm install');
  task.info(`Installing ${packagePath}`);

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
    stdio: stdioOptions || 'inherit'
  });

  // printing child process can interfere with following log line,
  // so we add a message here to prevent it breaking the end group
  task.info('apm install finished');
  task.done();
};
