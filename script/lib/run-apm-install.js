'use strict'

const childProcess = require('child_process')
const path = require('path')

const CONFIG = require('../config')

module.exports = function (packagePath) {
  const installEnv = Object.assign({}, process.env)
  // Set resource path so that apm can load metadata related to Atom.
  installEnv.ATOM_RESOURCE_PATH = CONFIG.repositoryRootPath
  // Set our target (Electron) version so that node-pre-gyp can download the
  // proper binaries.
  installEnv.npm_config_target = CONFIG.appMetadata.electronVersion;
  childProcess.execFileSync(
    CONFIG.getApmBinPath(),
    ['--loglevel=error', 'install'],
    {env: installEnv, cwd: packagePath, stdio: 'inherit'}
  )
}
