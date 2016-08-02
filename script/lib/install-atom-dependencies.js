'use strict'

const childProcess = require('child_process')
const path = require('path')

const CONFIG = require('../config')

module.exports = function () {
  const installEnv = Object.assign({}, process.env)
  // Set our target (Electron) version so that node-pre-gyp can download the
  // proper binaries.
  installEnv.npm_config_target = CONFIG.appMetadata.electronVersion;
  // Force 32-bit modules on Windows. (Ref.: https://github.com/atom/atom/issues/10450)
  if (process.platform === 'win32') {
    installEnv.npm_config_target_arch = 'ia32'
  }
  childProcess.execFileSync(
    CONFIG.apmBinPath,
    ['--loglevel=error', 'install'],
    {env: installEnv, cwd: CONFIG.repositoryRootPath, stdio: 'inherit'}
  )
}
