'use strict'

const childProcess = require('child_process')

const CONFIG = require('../config')

module.exports = function (ci) {
  console.log('Installing apm')
  childProcess.execFileSync(
    CONFIG.getNpmBinPath(),
    ['--global-style', '--loglevel=error', ci ? 'ci' : 'install'],
    {env: process.env, cwd: CONFIG.apmRootPath}
  )
}
