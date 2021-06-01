'use strict';

const childProcess = require('child_process');

const CONFIG = require('../config');

module.exports = function(packagePath, ci, stdioOptions) {
  const installEnv = Object.assign({}, process.env);
  // Set resource path so that apm can load metadata related to Atom.
  installEnv.ATOM_RESOURCE_PATH = CONFIG.repositoryRootPath;

  childProcess.execFileSync(CONFIG.getApmBinPath(), [ci ? 'ci' : 'install'], {
    env: installEnv,
    cwd: packagePath,
    stdio: stdioOptions || 'inherit'
  });
};
